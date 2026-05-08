import Foundation

/// Persists the most recently computed `[Insight]` to the shared App Group so
/// Home can show a top-insight card without re-running 90 days of HealthKit
/// queries on every appearance. Mirrors the `TodayPlanStore` pattern.
enum InsightsStore {

    private static let suiteName = "group.com.Finbar.FinApp"
    private static let key = "currentInsights"
    private static let timestampKey = "currentInsightsGeneratedAt"

    static func save(_ insights: [Insight]) {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = try? JSONEncoder().encode(insights) else { return }
        defaults.set(data, forKey: key)
        defaults.set(Date.now.timeIntervalSince1970, forKey: timestampKey)
    }

    /// Load cached insights. Returns nil if nothing has been saved yet, the
    /// cache is older than 7 days, or decoding fails.
    static func load() -> [Insight]? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: key),
              let insights = try? JSONDecoder().decode([Insight].self, from: data)
        else { return nil }

        let ts = defaults.double(forKey: timestampKey)
        let generatedAt = Date(timeIntervalSince1970: ts)
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .distantPast
        guard generatedAt >= weekAgo else { return nil }

        return insights
    }
}
