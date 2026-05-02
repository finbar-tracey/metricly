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
                             useKilograms: Bool = true, currentStreak: Int = 0) {
        guard WCSession.default.activationState == .activated else { return }
        let context: [String: Any] = [
            WatchMessageKey.exerciseList:  exercises,
            WatchMessageKey.todayPlan:     todayPlanName,
            WatchMessageKey.useKilograms:  useKilograms,
            WatchMessageKey.currentStreak: currentStreak
        ]
        try? WCSession.default.updateApplicationContext(context)
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
        default:
            break
        }

        lastSyncDate = .now
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
