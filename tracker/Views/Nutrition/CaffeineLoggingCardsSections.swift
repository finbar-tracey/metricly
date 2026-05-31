import SwiftUI

enum CaffeineLoggingCardsSections {

    typealias LogCaffeineCard = CaffeineLogCardSection.LogCaffeineCard

    static func quickLogCard(
        frequentSources: [CaffeineEngine.FrequentSource],
        onQuickLog: @escaping (String, Double) -> Void
    ) -> some View {
        CaffeineLogCardSection.quickLogCard(frequentSources: frequentSources, onQuickLog: onQuickLog)
    }

    static func dailyBudgetCard(todayTotalMg: Double, dailyLimit: Double) -> some View {
        CaffeineLogCardSection.dailyBudgetCard(todayTotalMg: todayTotalMg, dailyLimit: dailyLimit)
    }

    static func decayCard(
        from now: Date,
        entries: [CaffeineEntry],
        halfLife: Double,
        decayTint: Color
    ) -> some View {
        CaffeineLogCardSection.decayCard(from: now, entries: entries, halfLife: halfLife, decayTint: decayTint)
    }

    static func streakCard(streak: Int, daysSinceFreeDayText: String?) -> some View {
        CaffeineIntakeCardsSection.streakCard(streak: streak, daysSinceFreeDayText: daysSinceFreeDayText)
    }

    static func recentIntakeCard(
        entries: [CaffeineEntry],
        halfLife: Double,
        onEdit: @escaping (CaffeineEntry) -> Void,
        onDelete: @escaping (CaffeineEntry) -> Void
    ) -> some View {
        CaffeineIntakeCardsSection.recentIntakeCard(
            entries: entries,
            halfLife: halfLife,
            onEdit: onEdit,
            onDelete: onDelete
        )
    }

    static func timeOfDayCard(breakdown: [CaffeineEngine.TimeOfDaySlice]) -> some View {
        CaffeineIntakeCardsSection.timeOfDayCard(breakdown: breakdown)
    }
}
