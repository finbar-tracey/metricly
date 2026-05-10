import Foundation
import Combine
import WatchConnectivity
import SwiftData

// MARK: - PhoneConnectivityManager
//
// Lives on the iPhone. Handles all WCSession communication with the Apple Watch.
// Receives completed workout / cardio payloads and persists them via SwiftData.
// Pushes exercise library + today's plan context to the Watch.

@MainActor
final class PhoneConnectivityManager: NSObject, ObservableObject {

    static let shared = PhoneConnectivityManager()

    @Published var lastSyncDate: Date?

    // Injected by the app on launch — lets us write SwiftData records.
    var modelContext: ModelContext?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: - Push exercise library to Watch

    /// Call this whenever the user's exercise library changes, or on app foreground.
    func pushExerciseLibrary(exercises: [String], todayPlanName: String = "",
                             todayPlannedExercises: [String] = [],
                             useKilograms: Bool = true, currentStreak: Int = 0,
                             perExerciseRest: [String: Int] = [:]) {
        guard WCSession.default.activationState == .activated else { return }
        var context: [String: Any] = [
            WatchMessageKey.exerciseList:    exercises,
            WatchMessageKey.todayPlan:       todayPlanName,
            WatchMessageKey.todayExercises:  todayPlannedExercises,
            WatchMessageKey.useKilograms:    useKilograms,
            WatchMessageKey.currentStreak:   currentStreak
        ]
        if !perExerciseRest.isEmpty {
            context[WatchMessageKey.perExerciseRest] = perExerciseRest
        }
        try? WCSession.default.updateApplicationContext(context)
    }

    // MARK: - Active-workout state

    /// Publishes (or clears) the phone-side active workout so the Watch
    /// and its complications can show "In Progress · <name>" even though
    /// the workout is being run from iOS.
    ///
    /// Pass `nil`/empty values to clear when the workout finishes.
    /// Writes immediately to the shared App Group defaults (so the
    /// complication's next refresh sees the new state) and also pushes
    /// the change through `updateApplicationContext` for promptness.
    func publishActiveWorkout(name: String?, startedAt: Date?) {
        let defaults = UserDefaults(suiteName: "group.com.Finbar.FinApp")
        // Don't stomp on watch-hosted sessions — those clear themselves
        // via WatchWorkoutSessionManager when the wrist session ends.
        let source = defaults?.string(forKey: "watch.activeSource") ?? ""
        guard source != "watch" else { return }

        if let startedAt {
            defaults?.set(startedAt.timeIntervalSince1970, forKey: "watch.activeStartedAt")
            defaults?.set("phone", forKey: "watch.activeSource")
        } else {
            defaults?.removeObject(forKey: "watch.activeStartedAt")
            defaults?.removeObject(forKey: "watch.activeSource")
        }
        if let name, !name.isEmpty {
            defaults?.set(name, forKey: "watch.activeName")
        } else {
            defaults?.removeObject(forKey: "watch.activeName")
        }

        guard WCSession.default.activationState == .activated else { return }
        var context: [String: Any] = [:]
        context[WatchMessageKey.activeStartedAt] = startedAt?.timeIntervalSince1970 ?? 0
        context[WatchMessageKey.activeName]      = name ?? ""
        // Merge with any existing context so we don't clobber the library
        // push above on the next read.
        var merged = WCSession.default.applicationContext
        merged.merge(context) { _, new in new }
        try? WCSession.default.updateApplicationContext(merged)
    }

    // MARK: - Private: receive & persist

    private func handleIncoming(userInfo: [String: Any]) {
        guard let typeRaw = userInfo[WatchMessageKey.type] as? String,
              let type    = WatchMessageType(rawValue: typeRaw)
        else { return }

        switch type {
        case .syncWorkout:
            if let data    = userInfo[WatchMessageKey.workoutPayload] as? Data,
               let payload = try? JSONDecoder().decode(WatchWorkoutPayload.self, from: data) {
                persistWorkout(payload)
            }
        case .syncCardio:
            if let data    = userInfo[WatchMessageKey.cardioPayload] as? Data,
               let payload = try? JSONDecoder().decode(WatchCardioPayload.self, from: data) {
                persistCardio(payload)
            }
        case .finishActiveWorkout:
            finishActiveWorkout()
        default:
            break
        }

        lastSyncDate = .now
    }

    /// Watch requested we finish the phone's in-progress workout. Mirrors
    /// the local Finish path without the rating/notes prompt — those can be
    /// added later by editing the workout. HealthKit save still runs when
    /// the user has the sync toggled on.
    private func finishActiveWorkout() {
        guard let ctx = modelContext else { return }
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { !$0.isTemplate && $0.endTime == nil },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let workout = (try? ctx.fetch(descriptor))?.first else {
            // No in-progress workout to finish — at least clear stale state
            // so the watch banner / complication don't keep showing it.
            publishActiveWorkout(name: nil, startedAt: nil)
            return
        }
        workout.endTime = .now
        try? ctx.save()

        // End live activity + clear the shared state so the watch banner
        // and complication update immediately.
        let totalSets = workout.exercises.flatMap(\.sets).count
        WorkoutActivityManager.shared.endActivity(
            exerciseCount: workout.exercises.count,
            setCount: totalSets
        )
        publishActiveWorkout(name: nil, startedAt: nil)

        // Best-effort HealthKit save if the user opted in.
        let settings = (try? ctx.fetch(FetchDescriptor<UserSettings>()))?.first
        if settings?.healthKitEnabled == true {
            Task { try? await HealthKitManager.shared.saveStrengthWorkout(workout) }
        }
    }

    // MARK: - SwiftData persistence

    private func persistWorkout(_ payload: WatchWorkoutPayload) {
        guard let ctx = modelContext else { return }

        let workout     = Workout(name: payload.name, date: payload.startDate)
        workout.endTime = payload.endDate
        ctx.insert(workout)

        for (order, ex) in payload.exercises.enumerated() {
            let exercise = Exercise(name: ex.name, workout: workout)
            exercise.order    = order
            ctx.insert(exercise)
            workout.exercises.append(exercise)

            for setPayload in ex.sets {
                let set = ExerciseSet(
                    reps:     setPayload.reps,
                    weight:   setPayload.weightKg,
                    isWarmUp: setPayload.isWarmUp,
                    exercise: exercise
                )
                ctx.insert(set)
                exercise.sets.append(set)
            }
        }

        try? ctx.save()

        // Notify UI to refresh
        NotificationCenter.default.post(name: .watchWorkoutReceived, object: nil)
    }

    private func persistCardio(_ payload: WatchCardioPayload) {
        guard let ctx = modelContext else { return }

        let session = CardioSession(
            date:            payload.date,
            title:           payload.activityTypeRaw,
            type:            CardioType(rawValue: payload.activityTypeRaw) ?? .outdoorRun,
            durationSeconds: payload.durationSeconds,
            distanceMeters:  payload.distanceMeters,
            elevationGainMeters: payload.elevationGain
        )
        session.avgHeartRate    = payload.avgHeartRate
        session.maxHeartRate    = payload.maxHeartRate
        session.caloriesBurned  = payload.calories
        ctx.insert(session)
        try? ctx.save()

        NotificationCenter.default.post(name: .watchCardioReceived, object: nil)
    }
}

// MARK: - WCSessionDelegate

extension PhoneConnectivityManager: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in self.handleIncoming(userInfo: userInfo) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                             replyHandler: @escaping ([String: Any]) -> Void) {
        // Watch is requesting the exercise library
        guard let typeRaw = message[WatchMessageKey.type] as? String,
              WatchMessageType(rawValue: typeRaw) == .requestData
        else { replyHandler([:]); return }

        Task { @MainActor in
            guard let ctx = self.modelContext else { replyHandler([:]); return }
            let descriptor = FetchDescriptor<Exercise>(
                sortBy: [SortDescriptor(\.name)]
            )
            let exercises = (try? ctx.fetch(descriptor))?.map(\.name) ?? []
            let unique    = Array(Set(exercises)).sorted()
            replyHandler([
                WatchMessageKey.exerciseList: Array(unique.prefix(50))
            ])
        }
    }
}

// MARK: - Notification names

extension Notification.Name {
    static let watchWorkoutReceived = Notification.Name("watchWorkoutReceived")
    static let watchCardioReceived  = Notification.Name("watchCardioReceived")
}
