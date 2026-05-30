import Foundation
import WatchConnectivity
import WidgetKit

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

    @Published var recentExercises:    [String] = []
    @Published var todayPlanName:      String   = ""
    /// Names of the exercises the iPhone says belong to today's planned
    /// workout. Used to pre-populate the gym session on Start.
    @Published var todayPlannedExercises: [String] = []
    @Published var isPhoneReachable:   Bool     = false
    @Published var useKg:              Bool     = true
    @Published var currentStreak:      Int      = 0
    @Published var restDuration:       Int      = 60   // seconds, global fallback
    /// Per-exercise overrides pushed from the iPhone. Looked up via
    /// `restDuration(for:)` — falls back to `restDuration` on miss.
    @Published var perExerciseRest:    [String: Int] = [:]
    /// Phone-side active workout, if any. Set when the user starts a
    /// workout on iPhone; cleared on finish. The Watch's start screen
    /// surfaces it so the user knows where their session is running.
    @Published var phoneActiveName:    String   = ""
    @Published var phoneActiveStartedAt: Date?  = nil

    /// Engine-recommended workout for today. Differs from `todayPlanName`
    /// (which is the schedule's literal label) when the adaptive plan
    /// nudged things — e.g. schedule says "Push" but recovery is low so the
    /// engine suggests "Recovery". Empty string means the phone hasn't
    /// computed a plan yet.
    @Published var adaptivePlanName:   String   = ""
    /// `TodayPlan.Intensity.rawValue` — "rest"/"light"/"moderate"/"hard".
    /// Drives the badge color on the gym start screen.
    @Published var adaptiveIntensity:  String   = ""
    /// First reason from the engine's reason list ("Recovery is low (32%)"
    /// etc). Shown beneath the recommendation as a one-liner so the user
    /// understands *why* the watch is suggesting what it is.
    @Published var adaptiveTopReason:  String   = ""
    /// `TrainingBlock.Phase.rawValue` of the user's active block ("accumulate"
    /// or "deload"), or `""` when no block is active. The watch's gym start
    /// screen drops the periodisation strip entirely when this is empty
    /// rather than rendering a half-filled row.
    @Published var blockPhase:         String   = ""
    /// Pre-formatted "Week N of M" label for the active block, or `""`.
    /// The phone does the date math once at the source so this is plain
    /// text on arrival — the watch never needs to call into engine code.
    @Published var blockWeekLabel:     String   = ""

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

    // MARK: - Request iPhone to finish its active workout

    /// Sends a "finish your active workout" request to the paired iPhone.
    /// Uses transferUserInfo so the request survives the phone being asleep
    /// or out of reach — it'll deliver when the phone next runs.
    ///
    /// Clears local phone-active state optimistically so the banner
    /// disappears immediately; the phone's eventual publish will confirm.
    func sendFinishActiveWorkout() {
        guard WCSession.default.activationState == .activated else { return }
        WCSession.default.transferUserInfo([
            WatchMessageKey.type: WatchMessageType.finishActiveWorkout.rawValue
        ])
        phoneActiveName = ""
        phoneActiveStartedAt = nil
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
        let defaults = UserDefaults(suiteName: WatchSharedKeys.suite)
        if let exercises = reply[WatchMessageKey.exerciseList] as? [String] {
            recentExercises = exercises
            defaults?.set(exercises, forKey: WatchSharedKeys.recentExercises)
        }
        if let plan = reply[WatchMessageKey.todayPlan] as? String {
            todayPlanName = plan
            defaults?.set(plan, forKey: WatchSharedKeys.todayPlanName)
        }
        if let planned = reply[WatchMessageKey.todayExercises] as? [String] {
            todayPlannedExercises = planned
            defaults?.set(planned, forKey: WatchSharedKeys.todayExercises)
        }
        if let kg = reply[WatchMessageKey.useKilograms] as? Bool {
            useKg = kg
            defaults?.set(kg, forKey: WatchSharedKeys.useKilograms)
        }
        if let streak = reply[WatchMessageKey.currentStreak] as? Int {
            currentStreak = streak
            defaults?.set(streak, forKey: WatchSharedKeys.currentStreak)
        }
        if let map = reply[WatchMessageKey.perExerciseRest] as? [String: Int] {
            perExerciseRest = map
            defaults?.set(map, forKey: WatchSharedKeys.perExerciseRest)
        }
        // Global rest fallback. Mirrors to the App Group so cold-launch
        // reads in `loadCachedData` see the user's actual setting, not
        // the watch's hardcoded 60s default.
        if let restSec = reply[WatchMessageKey.restDuration] as? Int, restSec > 0 {
            restDuration = restSec
            defaults?.set(restSec, forKey: WatchSharedKeys.restDuration)
        }
        // Adaptive plan — engine's recommendation for today. Persist to App
        // Group defaults so the values survive an app kill (we'd otherwise
        // wait for the next phone push, which may not arrive until the user
        // foregrounds the iPhone).
        if let aName = reply[WatchMessageKey.adaptivePlanName] as? String {
            adaptivePlanName = aName
            defaults?.set(aName, forKey: WatchSharedKeys.adaptivePlanName)
        }
        if let aInt = reply[WatchMessageKey.adaptiveIntensity] as? String {
            adaptiveIntensity = aInt
            defaults?.set(aInt, forKey: WatchSharedKeys.adaptiveIntensity)
        }
        if let aReason = reply[WatchMessageKey.adaptiveTopReason] as? String {
            adaptiveTopReason = aReason
            defaults?.set(aReason, forKey: WatchSharedKeys.adaptiveTopReason)
        }
        // Training block context — phase + "Week N of M" label.
        // Empty strings mean "no active block"; we still write them so
        // the App Group reflects the absence (otherwise a stale cached
        // value would survive after the block ended).
        if let phase = reply[WatchMessageKey.blockPhase] as? String {
            blockPhase = phase
            defaults?.set(phase, forKey: WatchSharedKeys.blockPhase)
        }
        if let label = reply[WatchMessageKey.blockWeekLabel] as? String {
            blockWeekLabel = label
            defaults?.set(label, forKey: WatchSharedKeys.blockWeekLabel)
        }
        // Phone-side active workout. A `0` (or missing) timestamp means
        // the phone has no active workout — clear local state.
        if let ts = reply[WatchMessageKey.activeStartedAt] as? Double {
            let started = ts > 0 ? Date(timeIntervalSince1970: ts) : nil
            let name = reply[WatchMessageKey.activeName] as? String ?? ""
            applyPhoneActiveState(name: name, startedAt: started)
        }
    }

    /// Writes phone-side active state to publishable fields, mirrors it to
    /// the App Group keys the complication reads, and kicks WidgetKit to
    /// refresh so the watch face updates within seconds rather than waiting
    /// for the next scheduled timeline reload.
    ///
    /// Skips ALL writes — both publishable and App Group — when the Watch
    /// is hosting its own session (source == "watch"). Two reasons:
    ///   1. `collectWatchContext` on the phone reads its mirror of the
    ///      App Group active state and round-trips it via WCSession reply.
    ///      When the watch owns the session, that round-trip arrives back
    ///      as a "phone push" with the watch's own start time — left
    ///      unguarded it would set phoneActiveStartedAt on the watch,
    ///      causing WatchGymView's `phoneActiveBanner` ("Workout on
    ///      iPhone") to fire alongside the active wrist view.
    ///   2. The complication would then flicker between "On iPhone" and
    ///      the watch's own session state on every phone foreground.
    private func applyPhoneActiveState(name: String, startedAt: Date?) {
        let defaults = UserDefaults(suiteName: WatchSharedKeys.suite)
        let source = defaults?.string(forKey: WatchSharedKeys.activeSource) ?? ""
        guard source != "watch" else { return }

        phoneActiveName = name
        phoneActiveStartedAt = startedAt

        if let startedAt {
            defaults?.set(startedAt.timeIntervalSince1970, forKey: WatchSharedKeys.activeStartedAt)
            defaults?.set(name, forKey: WatchSharedKeys.activeName)
            defaults?.set("phone", forKey: WatchSharedKeys.activeSource)
        } else {
            defaults?.removeObject(forKey: WatchSharedKeys.activeStartedAt)
            defaults?.removeObject(forKey: WatchSharedKeys.activeName)
            defaults?.removeObject(forKey: WatchSharedKeys.activeSource)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Looks up the rest duration for a specific exercise (case-insensitive),
    /// falling back to the global `restDuration` when no override exists.
    /// Use this when starting the rest timer so power lifters' "3 min for
    /// squats, 60 s for curls" rule actually works on the Watch.
    func restDuration(for exerciseName: String) -> Int {
        let key = exerciseName.lowercased()
        if let exact = perExerciseRest[exerciseName] { return exact }
        // Map keys may have been stored with original casing — check
        // lower-cased copy without rebuilding the dict every call.
        for (k, v) in perExerciseRest where k.lowercased() == key {
            return v
        }
        return restDuration
    }

    private func loadCachedData() {
        guard let defaults = UserDefaults(suiteName: WatchSharedKeys.suite) else { return }
        recentExercises       = defaults.stringArray(forKey: WatchSharedKeys.recentExercises) ?? []
        todayPlanName         = defaults.string(forKey: WatchSharedKeys.todayPlanName) ?? ""
        todayPlannedExercises = defaults.stringArray(forKey: WatchSharedKeys.todayExercises) ?? []
        useKg                 = defaults.object(forKey: WatchSharedKeys.useKilograms) as? Bool ?? true
        currentStreak         = defaults.integer(forKey: WatchSharedKeys.currentStreak)
        restDuration          = defaults.integer(forKey: WatchSharedKeys.restDuration).nonZero ?? 60
        perExerciseRest       = defaults.dictionary(forKey: WatchSharedKeys.perExerciseRest) as? [String: Int] ?? [:]
        adaptivePlanName      = defaults.string(forKey: WatchSharedKeys.adaptivePlanName) ?? ""
        adaptiveIntensity     = defaults.string(forKey: WatchSharedKeys.adaptiveIntensity) ?? ""
        adaptiveTopReason     = defaults.string(forKey: WatchSharedKeys.adaptiveTopReason) ?? ""
        blockPhase            = defaults.string(forKey: WatchSharedKeys.blockPhase) ?? ""
        blockWeekLabel        = defaults.string(forKey: WatchSharedKeys.blockWeekLabel) ?? ""

        // Cold-launch: if the phone wrote an active workout earlier and
        // the watch app was killed in the interim, surface it on first
        // render.
        //
        // Source disambiguation:
        // - `"watch"`: stale wrist session (watch sessions don't survive a
        //    kill) — ignore so we don't show a phantom "On iPhone" banner.
        // - `"phone"`: phone published it — restore.
        // - `""` (empty): also restore. This is the cold-launch escape
        //    hatch for an older build or any partial-write where the
        //    source key didn't make it but the timestamp did. The
        //    failure mode of trusting it (one stale banner for a few
        //    seconds until the phone confirms or clears) is much
        //    cheaper than the silent-drop failure mode of requiring it.
        let ts = defaults.double(forKey: WatchSharedKeys.activeStartedAt)
        let source = defaults.string(forKey: WatchSharedKeys.activeSource) ?? ""
        if ts > 0 && source != "watch" {
            phoneActiveStartedAt = Date(timeIntervalSince1970: ts)
            phoneActiveName = defaults.string(forKey: WatchSharedKeys.activeName) ?? ""
        }
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
