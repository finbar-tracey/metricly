import Foundation

/// Persists `TodayPlan`s to the shared App Group so views (and eventually
/// widgets / Watch) can read them without recomputing.
///
/// Two persistence paths:
/// - `save(_:)` / `load()` — the legacy single-slot for "today's plan",
///   kept because widgets + the home view drive off it.
/// - `history()` / `plan(on:)` — a rolling window of the last
///   `historyLimit` days' plans, keyed by the day they were generated
///   for. Used by the compliance backfill to figure out what the
///   engine had suggested on each historical day.
///
/// Both slots are written by `save(_:)`; readers pick the one that
/// fits their need.
enum TodayPlanStore {

    private static let suiteName = WidgetAppGroup.suiteName
    private static let currentKey = "currentTodayPlan"
    private static let historyKey = "todayPlanHistory"

    /// Maximum number of past days to retain in the rolling window.
    /// Matches the compliance backfill's lookback so we never drop a
    /// day the engine still needs.
    static let historyLimit: Int = 14

    // MARK: - Single-slot (today's plan)

    /// Persist the plan. Writes both the single-slot cache (for the
    /// existing widget/home reads) and the rolling history (for the
    /// compliance backfill). Safe to call frequently — JSON is small.
    static func save(_ plan: TodayPlan) {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = try? JSONEncoder().encode(plan) else { return }
        defaults.set(data, forKey: currentKey)
        appendToHistory(plan, defaults: defaults)
    }

    /// Load the most recently saved plan. Returns nil if nothing has
    /// been saved yet, the plan is from a previous calendar day, or
    /// decoding fails.
    static func load() -> TodayPlan? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: currentKey),
              let plan = try? JSONDecoder().decode(TodayPlan.self, from: data)
        else { return nil }

        // Stale plans from previous days shouldn't influence today's workout.
        guard Calendar.current.isDateInToday(plan.generatedAt) else { return nil }
        return plan
    }

    // MARK: - Rolling history

    /// All retained plans, sorted newest-first by their generation date.
    /// Each calendar day appears at most once — when the same day is
    /// saved multiple times the latest version wins.
    static func history() -> [TodayPlan] {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: historyKey),
              let plans = try? JSONDecoder().decode([TodayPlan].self, from: data)
        else { return [] }
        return plans.sorted { $0.generatedAt > $1.generatedAt }
    }

    /// The plan that was active on the given day, if one was saved
    /// while that day was current. Returns nil for days the user
    /// didn't open the app on.
    static func plan(on day: Date) -> TodayPlan? {
        let target = Calendar.current.startOfDay(for: day)
        return history().first {
            Calendar.current.startOfDay(for: $0.generatedAt) == target
        }
    }

    /// Clears persisted plan slots — for unit tests only.
    static func resetForTests() {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        defaults.removeObject(forKey: currentKey)
        defaults.removeObject(forKey: historyKey)
    }

    // MARK: - Private

    private static func appendToHistory(_ plan: TodayPlan, defaults: UserDefaults) {
        var all = history()
        let cal = Calendar.current
        let planDay = cal.startOfDay(for: plan.generatedAt)
        // Drop any prior plan for the same day — the latest write wins.
        all.removeAll { cal.startOfDay(for: $0.generatedAt) == planDay }
        all.insert(plan, at: 0)
        // Prune anything older than the lookback window so the App
        // Group cache doesn't grow unbounded.
        let cutoff = cal.date(byAdding: .day, value: -historyLimit, to: .now) ?? .distantPast
        all.removeAll { $0.generatedAt < cutoff }
        if let data = try? JSONEncoder().encode(all) {
            defaults.set(data, forKey: historyKey)
        }
    }
}
