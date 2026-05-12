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

    // MARK: - Watch context (single source of truth)
    //
    // The Watch has two ways to receive context: an `updateApplicationContext`
    // push from the phone (on foreground / data change) and a reply to its
    // own `requestData` message. Previously these built different payloads
    // — the push sent the full set, the reply only sent `exerciseList` —
    // so a Watch app that came up before the phone had pushed would get
    // a stale view (no plan name, no streak, no rest overrides).
    //
    // `collectWatchContext()` builds the canonical dict from SwiftData;
    // `pushWatchContext()` and the `didReceiveMessage` reply both call it.

    /// Build the full Watch payload from current SwiftData state. Pure
    /// — does not send anything. Callers decide whether to push, reply,
    /// or both.
    @MainActor
    func collectWatchContext() -> [String: Any] {
        guard let ctx = modelContext else { return [:] }

        let settings = (try? ctx.fetch(FetchDescriptor<UserSettings>()))?.first
        let weekday  = Calendar.current.component(.weekday, from: .now)
        let todayPlanName = settings?.weeklyPlan[weekday] ?? ""
        let useKg = settings?.useKilograms ?? true

        let allExercises = (try? ctx.fetch(FetchDescriptor<Exercise>(
            sortBy: [SortDescriptor(\.name)]
        ))) ?? []
        let uniqueNames = Array(Set(allExercises.map(\.name))).sorted().prefix(50)

        let workouts = (try? ctx.fetch(FetchDescriptor<Workout>())) ?? []
        let cardio   = (try? ctx.fetch(FetchDescriptor<CardioSession>())) ?? []
        let streak   = Workout.currentStreak(from: workouts, cardioSessions: Array(cardio.prefix(60)))

        // Today's planned exercises = the most recent finished workout
        // whose name matches today's plan.
        let plannedExercises: [String] = {
            guard !todayPlanName.isEmpty else { return [] }
            let match = workouts
                .filter { !$0.isTemplate && $0.endTime != nil
                          && $0.name.localizedCaseInsensitiveCompare(todayPlanName) == .orderedSame }
                .max(by: { $0.date < $1.date })
            return match?.exercises.sorted { $0.order < $1.order }.map(\.name) ?? []
        }()

        // Per-exercise rest map: walk the library, collapse by lowercased
        // name, keep the most-recently-edited override.
        var perRest: [String: Int] = [:]
        var seenKeys = Set<String>()
        for ex in allExercises.reversed() where ex.customRestDuration != nil {
            let key = ex.name.lowercased()
            guard !seenKeys.contains(key) else { continue }
            seenKeys.insert(key)
            perRest[ex.name] = ex.customRestDuration
        }

        // Active-workout state — read from shared defaults rather than
        // recomputing here, so we don't stomp on a watch-hosted session
        // that owns the state right now.
        let defaults = UserDefaults(suiteName: "group.com.Finbar.FinApp")
        let activeStartedAt = defaults?.double(forKey: "watch.activeStartedAt") ?? 0
        let activeName = defaults?.string(forKey: "watch.activeName") ?? ""

        var context: [String: Any] = [
            WatchMessageKey.exerciseList:    Array(uniqueNames),
            WatchMessageKey.todayPlan:       todayPlanName,
            WatchMessageKey.todayExercises:  plannedExercises,
            WatchMessageKey.useKilograms:    useKg,
            WatchMessageKey.currentStreak:   streak,
            WatchMessageKey.activeStartedAt: activeStartedAt,
            WatchMessageKey.activeName:      activeName
        ]
        if !perRest.isEmpty {
            context[WatchMessageKey.perExerciseRest] = perRest
        }
        return context
    }

    /// Push the full context via WCSession application context. Also writes
    /// to the App Group defaults so cold-launched watch reads (before
    /// WCSession activates) see the same state.
    @MainActor
    func pushWatchContext() {
        let context = collectWatchContext()
        // Mirror to shared defaults for cold-launch reads on the Watch.
        if let defaults = UserDefaults(suiteName: "group.com.Finbar.FinApp") {
            if let useKg    = context[WatchMessageKey.useKilograms] as? Bool {
                defaults.set(useKg,    forKey: "watch.useKilograms")
            }
            if let streak   = context[WatchMessageKey.currentStreak] as? Int {
                defaults.set(streak,   forKey: "watch.currentStreak")
            }
            if let planName = context[WatchMessageKey.todayPlan] as? String {
                defaults.set(planName, forKey: "watch.todayPlanName")
            }
            if let planned  = context[WatchMessageKey.todayExercises] as? [String] {
                defaults.set(planned,  forKey: "watch.todayExercises")
            }
            if let perRest  = context[WatchMessageKey.perExerciseRest] as? [String: Int] {
                defaults.set(perRest,  forKey: "watch.perExerciseRest")
            }
        }

        guard WCSession.default.activationState == .activated else { return }
        try? WCSession.default.updateApplicationContext(context)
    }

    // MARK: - Per-exercise rest overrides

    /// Push only the per-exercise rest map. Used when an override is edited
    /// mid-session — we don't want to wait for the next foreground re-push
    /// of the full exercise library before the Watch's rest timer respects
    /// the new value.
    ///
    /// Merges into the existing application context rather than overwriting
    /// it so the watch keeps the other state (exercise list, today's plan,
    /// streak, useKg) unchanged.
    ///
    /// Also writes to the shared App Group defaults so a cold-launched watch
    /// or complication reads the same overrides without WCSession.
    func pushRestOverrides(_ map: [String: Int]) {
        let defaults = UserDefaults(suiteName: "group.com.Finbar.FinApp")
        defaults?.set(map, forKey: "watch.perExerciseRest")

        guard WCSession.default.activationState == .activated else { return }
        var merged = WCSession.default.applicationContext
        merged[WatchMessageKey.perExerciseRest] = map
        try? WCSession.default.updateApplicationContext(merged)
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
        // Watch requesting full data sync. Reply with the same canonical
        // context the foreground push uses — previously this only sent
        // `exerciseList`, leaving the Watch with stale (or empty) plan
        // name, streak, rest overrides, and active workout state until
        // the next iPhone foreground.
        guard let typeRaw = message[WatchMessageKey.type] as? String,
              WatchMessageType(rawValue: typeRaw) == .requestData
        else { replyHandler([:]); return }

        Task { @MainActor in
            replyHandler(self.collectWatchContext())
        }
    }
}

// MARK: - Notification names

extension Notification.Name {
    static let watchWorkoutReceived = Notification.Name("watchWorkoutReceived")
    static let watchCardioReceived  = Notification.Name("watchCardioReceived")
}
