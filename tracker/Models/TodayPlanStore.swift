import Foundation

/// Persists the most recently computed `TodayPlan` to the shared App Group so
/// any view (and eventually widgets / Watch) can read it without recomputing.
/// The plan is small enough that App Group `UserDefaults` is fine — we don't
/// need a real database for this.
enum TodayPlanStore {

    private static let suiteName = "group.com.Finbar.FinApp"
    private static let key = "currentTodayPlan"

    /// Persist the plan. Safe to call frequently — JSON is small.
    static func save(_ plan: TodayPlan) {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = try? JSONEncoder().encode(plan) else { return }
        defaults.set(data, forKey: key)
    }

    /// Load the most recently saved plan. Returns nil if nothing has been saved
    /// yet, the plan is from a previous calendar day, or decoding fails.
    static func load() -> TodayPlan? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: key),
              let plan = try? JSONDecoder().decode(TodayPlan.self, from: data)
        else { return nil }

        // Stale plans from previous days shouldn't influence today's workout.
        guard Calendar.current.isDateInToday(plan.generatedAt) else { return nil }
        return plan
    }
}
