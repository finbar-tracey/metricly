import Foundation
import WatchConnectivity

private extension Int {
    /// Returns nil when the Int is zero (useful for UserDefaults "not set" detection).
    var nonZero: Int? { self == 0 ? nil : self }
}

// MARK: - WatchConnectivityManager (Watch side)
//
// Handles all WCSession communication between Watch and iPhone.
// Sends completed workout/cardio payloads to iPhone.
// Receives exercise library and today's plan from iPhone.

@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject {

    static let shared = WatchConnectivityManager()

    @Published var recentExercises:  [String] = []
    @Published var todayPlanName:    String   = ""
    @Published var isPhoneReachable: Bool     = false
    @Published var useKg:            Bool     = true
    @Published var currentStreak:    Int      = 0
    @Published var restDuration:     Int      = 60   // seconds

    private override init() {
        super.init()
        loadCachedData()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: - Send completed gym workout to iPhone

    func sendWorkout(_ payload: WatchWorkoutPayload) {
        guard WCSession.default.activationState == .activated else { return }
        guard let data = try? JSONEncoder().encode(payload) else { return }
        let info: [String: Any] = [
            WatchMessageKey.type: WatchMessageType.syncWorkout.rawValue,
            WatchMessageKey.workoutPayload: data
        ]
        // transferUserInfo is reliable even when iPhone isn't reachable right now
        WCSession.default.transferUserInfo(info)
    }

    // MARK: - Send completed cardio session to iPhone

    func sendCardio(_ payload: WatchCardioPayload) {
        guard WCSession.default.activationState == .activated else { return }
        guard let data = try? JSONEncoder().encode(payload) else { return }
        let info: [String: Any] = [
            WatchMessageKey.type: WatchMessageType.syncCardio.rawValue,
            WatchMessageKey.cardioPayload: data
        ]
        WCSession.default.transferUserInfo(info)
    }

    // MARK: - Request exercise data from iPhone (when reachable)

    func requestExerciseData() {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(
            [WatchMessageKey.type: WatchMessageType.requestData.rawValue],
            replyHandler: { [weak self] reply in
                Task { @MainActor in
                    self?.handleExerciseDataReply(reply)
                }
            },
            errorHandler: nil
        )
    }

    // MARK: - Private

    private func handleExerciseDataReply(_ reply: [String: Any]) {
        if let exercises = reply[WatchMessageKey.exerciseList] as? [String] {
            recentExercises = exercises
            saveToSharedDefaults(exercises: exercises)
        }
        if let plan = reply[WatchMessageKey.todayPlan] as? String {
            todayPlanName = plan
        }
        if let kg = reply[WatchMessageKey.useKilograms] as? Bool {
            useKg = kg
            UserDefaults(suiteName: WatchSharedKeys.suite)?.set(kg, forKey: WatchSharedKeys.useKilograms)
        }
        if let streak = reply[WatchMessageKey.currentStreak] as? Int {
            currentStreak = streak
            UserDefaults(suiteName: WatchSharedKeys.suite)?.set(streak, forKey: WatchSharedKeys.currentStreak)
        }
    }

    private func loadCachedData() {
        guard let defaults = UserDefaults(suiteName: WatchSharedKeys.suite) else { return }
        recentExercises = defaults.stringArray(forKey: WatchSharedKeys.recentExercises) ?? []
        todayPlanName   = defaults.string(forKey: WatchSharedKeys.todayPlanName) ?? ""
        useKg           = defaults.object(forKey: WatchSharedKeys.useKilograms) as? Bool ?? true
        currentStreak   = defaults.integer(forKey: WatchSharedKeys.currentStreak)
        restDuration    = defaults.integer(forKey: WatchSharedKeys.restDuration).nonZero ?? 60
    }

    private func saveToSharedDefaults(exercises: [String]) {
        guard let defaults = UserDefaults(suiteName: WatchSharedKeys.suite) else { return }
        defaults.set(exercises, forKey: WatchSharedKeys.recentExercises)
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isPhoneReachable = session.isReachable
            if activationState == .activated {
                self.requestExerciseData()
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isPhoneReachable = session.isReachable
            if session.isReachable {
                self.requestExerciseData()
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        // iPhone pushed updated exercise list / today's plan
        Task { @MainActor in
            self.handleExerciseDataReply(applicationContext)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        // Receive pushed data from iPhone (e.g., updated exercise list)
        Task { @MainActor in
            self.handleExerciseDataReply(userInfo)
        }
    }
}
