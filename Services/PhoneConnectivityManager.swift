import Foundation
import Combine
import WatchConnectivity
import SwiftData
import WidgetKit

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
        return WatchContextBuilder.build(from: ctx)
    }

    /// Push the full context via WCSession application context, and
    /// mirror it to the iPhone's App Group defaults for the home-screen
    /// widgets and Live Activity to read.
    ///
    /// **Why the mirror exists.** App Groups are NOT shared between
    /// iPhone and Apple Watch — each device has its own UserDefaults
    /// store under the same suite identifier. Writing here does NOT
    /// make the watch see these values. The watch's cold-launch reads
    /// come from the WATCH'S App Group, which is populated by the
    /// watch's own `WatchConnectivityManager.handleExerciseDataReply`
    /// mirroring the incoming WCSession payload to its local defaults.
    ///
    /// So the mirror below serves two iPhone-side readers:
    ///   1. The widget extension (`MetriclyWidgets`), which reads
    ///      `watch.todayPlanName` / `watch.adaptivePlanName` / etc. to
    ///      render the home-screen complications.
    ///   2. The watch *complication* extension on first install —
    ///      complications can run before the watch app has activated
    ///      WCSession, but they read their own App Group, populated by
    ///      the watch app's prior WCSession receive.
    ///
    /// Phone-to-watch communication is exclusively via WCSession.
    /// updateApplicationContext below.
    @MainActor
    func pushWatchContext() {
        let context = collectWatchContext()
        // Mirror to the iPhone's shared defaults — widget readers + the
        // watch complication's own cold cache (which is fed via the
        // watch app's WCSession receive, not directly from this write).
        if let defaults = UserDefaults(suiteName: WidgetAppGroup.suiteName) {
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
            if let restSec  = context[WatchMessageKey.restDuration] as? Int {
                defaults.set(restSec,  forKey: "watch.restDuration")
            }
            // Adaptive plan mirror — iPhone-side widgets (and the
            // watch complication's cold cache via its own WCSession
            // receive — not directly from this write) read these.
            if let aName = context[WatchMessageKey.adaptivePlanName] as? String {
                defaults.set(aName, forKey: "watch.adaptivePlanName")
            }
            if let aInt = context[WatchMessageKey.adaptiveIntensity] as? String {
                defaults.set(aInt, forKey: "watch.adaptiveIntensity")
            }
            if let aReason = context[WatchMessageKey.adaptiveTopReason] as? String {
                defaults.set(aReason, forKey: "watch.adaptiveTopReason")
            }
            // Block context mirror — iPhone-side widgets read these to
            // render "Wk 2/4 · Deload" next to the adaptive plan;
            // matches the same pattern as the adaptive trio above.
            if let phase = context[WatchMessageKey.blockPhase] as? String {
                defaults.set(phase, forKey: "watch.blockPhase")
            }
            if let weekLabel = context[WatchMessageKey.blockWeekLabel] as? String {
                defaults.set(weekLabel, forKey: "watch.blockWeekLabel")
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
        let defaults = UserDefaults(suiteName: WidgetAppGroup.suiteName)
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
        let defaults = UserDefaults(suiteName: WidgetAppGroup.suiteName)
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

        // Kick the home-screen widgets and watch complications so the
        // "In Progress · <name>" state appears within seconds rather than
        // waiting for their next scheduled timeline reload (which can be
        // 30–60 minutes off when the system is being thrifty). The watch
        // side does the same in WatchWorkoutSessionManager — this matches
        // the symmetry.
        WidgetCenter.shared.reloadAllTimelines()

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
}
