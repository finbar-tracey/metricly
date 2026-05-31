import SwiftUI

/// Thin facade over split caffeine section modules (logging vs history).
enum CaffeineTrackerSections {
    typealias LogCaffeineCard = CaffeineLoggingSections.LogCaffeineCard
    typealias HistorySection = CaffeineHistorySections.HistorySection

    static func decayTint(colorScheme: ColorScheme) -> Color {
        CaffeineLoggingSections.decayTint(colorScheme: colorScheme)
    }

    static func sleepReadinessPresentation(_ mg: Double) -> (label: String, color: Color, icon: String) {
        CaffeineLoggingSections.sleepReadinessPresentation(mg)
    }

    static func heroCard(
        remaining: Double,
        readiness: (label: String, color: Color, icon: String),
        now: Date,
        entries: [CaffeineEntry],
        halfLife: Double,
        dailyLimit: Double,
        todayTotalMg: Double
    ) -> some View {
        CaffeineLoggingSections.heroCard(
            remaining: remaining,
            readiness: readiness,
            now: now,
            entries: entries,
            halfLife: halfLife,
            dailyLimit: dailyLimit,
            todayTotalMg: todayTotalMg
        )
    }

    static func quickLogCard(
        frequentSources: [CaffeineEngine.FrequentSource],
        onQuickLog: @escaping (String, Double) -> Void
    ) -> some View {
        CaffeineLoggingSections.quickLogCard(frequentSources: frequentSources, onQuickLog: onQuickLog)
    }

    static func dailyBudgetCard(todayTotalMg: Double, dailyLimit: Double) -> some View {
        CaffeineLoggingSections.dailyBudgetCard(todayTotalMg: todayTotalMg, dailyLimit: dailyLimit)
    }

    static func decayCard(
        from now: Date,
        entries: [CaffeineEntry],
        halfLife: Double,
        decayTint: Color
    ) -> some View {
        CaffeineLoggingSections.decayCard(from: now, entries: entries, halfLife: halfLife, decayTint: decayTint)
    }

    static func streakCard(streak: Int, daysSinceFreeDayText: String?) -> some View {
        CaffeineLoggingSections.streakCard(streak: streak, daysSinceFreeDayText: daysSinceFreeDayText)
    }

    static func recentIntakeCard(
        entries: [CaffeineEntry],
        halfLife: Double,
        onEdit: @escaping (CaffeineEntry) -> Void,
        onDelete: @escaping (CaffeineEntry) -> Void
    ) -> some View {
        CaffeineLoggingSections.recentIntakeCard(
            entries: entries,
            halfLife: halfLife,
            onEdit: onEdit,
            onDelete: onDelete
        )
    }

    static func timeOfDayCard(breakdown: [CaffeineEngine.TimeOfDaySlice]) -> some View {
        CaffeineLoggingSections.timeOfDayCard(breakdown: breakdown)
    }
}
