import SwiftUI

/// Caffeine tracker UI sections — logging, hero/decay, history on `MetricDetailScaffold`.
enum CaffeineLoggingSections {

    typealias LogCaffeineCard = CaffeineLoggingCardsSections.LogCaffeineCard

    static func decayTint(colorScheme: ColorScheme) -> Color {
        CaffeineLoggingHeroSections.decayTint(colorScheme: colorScheme)
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
        CaffeineLoggingHeroSections.heroCard(
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
        CaffeineLoggingCardsSections.quickLogCard(frequentSources: frequentSources, onQuickLog: onQuickLog)
    }

    static func dailyBudgetCard(todayTotalMg: Double, dailyLimit: Double) -> some View {
        CaffeineLoggingCardsSections.dailyBudgetCard(todayTotalMg: todayTotalMg, dailyLimit: dailyLimit)
    }

    static func decayCard(
        from now: Date,
        entries: [CaffeineEntry],
        halfLife: Double,
        decayTint: Color
    ) -> some View {
        CaffeineLoggingCardsSections.decayCard(from: now, entries: entries, halfLife: halfLife, decayTint: decayTint)
    }

    static func streakCard(streak: Int, daysSinceFreeDayText: String?) -> some View {
        CaffeineLoggingCardsSections.streakCard(streak: streak, daysSinceFreeDayText: daysSinceFreeDayText)
    }

    static func recentIntakeCard(
        entries: [CaffeineEntry],
        halfLife: Double,
        onEdit: @escaping (CaffeineEntry) -> Void,
        onDelete: @escaping (CaffeineEntry) -> Void
    ) -> some View {
        CaffeineLoggingCardsSections.recentIntakeCard(
            entries: entries,
            halfLife: halfLife,
            onEdit: onEdit,
            onDelete: onDelete
        )
    }

    static func sleepReadinessPresentation(_ mg: Double) -> (label: String, color: Color, icon: String) {
        CaffeineLoggingHeroSections.sleepReadinessPresentation(mg)
    }

    static func timeOfDayCard(breakdown: [CaffeineEngine.TimeOfDaySlice]) -> some View {
        CaffeineLoggingCardsSections.timeOfDayCard(breakdown: breakdown)
    }
}
