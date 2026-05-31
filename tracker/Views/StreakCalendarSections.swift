import SwiftUI

enum StreakCalendarSections {

    @ViewBuilder
    static func nextMilestoneCard(
        currentStreak: Int,
        longestStreak: Int
    ) -> some View {
        StreakCalendarHeroSections.nextMilestoneCard(
            currentStreak: currentStreak,
            longestStreak: longestStreak
        )
    }

    static func heroCard(
        currentStreak: Int,
        longestStreak: Int,
        thisWeekCount: Int,
        thisMonthCount: Int,
        totalWorkouts: Int
    ) -> some View {
        StreakCalendarHeroSections.heroCard(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            thisWeekCount: thisWeekCount,
            thisMonthCount: thisMonthCount,
            totalWorkouts: totalWorkouts
        )
    }

    static func restDayCard(currentStreak: Int, onDismiss: @escaping () -> Void) -> some View {
        StreakCalendarHeroSections.restDayCard(currentStreak: currentStreak, onDismiss: onDismiss)
    }

    static func activityGridCard(
        activeDates: [Date: Int],
        monthsBack: Int
    ) -> some View {
        StreakCalendarGridSections.activityGridCard(activeDates: activeDates, monthsBack: monthsBack)
    }

    static func monthlyCard(monthlyBreakdown: [(label: String, count: Int)]) -> some View {
        StreakCalendarGridSections.monthlyCard(monthlyBreakdown: monthlyBreakdown)
    }

    static func statsCard(
        currentStreak: Int,
        longestStreak: Int,
        thisWeekCount: Int,
        thisMonthCount: Int
    ) -> some View {
        StreakCalendarGridSections.statsCard(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            thisWeekCount: thisWeekCount,
            thisMonthCount: thisMonthCount
        )
    }
}
