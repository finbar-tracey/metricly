import SwiftUI

enum WaterTrackerSections {

    typealias TimeBlock = WaterTrackerDataSections.TimeBlock

    static func dailyTotals(
        allEntries: [WaterEntry],
        days: Int,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [(date: Date, ml: Double)] {
        WaterTrackerDataSections.dailyTotals(allEntries: allEntries, days: days, now: now, calendar: calendar)
    }

    static func weeklyStats(
        allEntries: [WaterEntry],
        days: Int,
        goalMl: Double,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> (avg: Double, daysMetGoal: Int, totalDays: Int) {
        WaterTrackerDataSections.weeklyStats(
            allEntries: allEntries,
            days: days,
            goalMl: goalMl,
            now: now,
            calendar: calendar
        )
    }

    static func hydrationStreak(
        allEntries: [WaterEntry],
        todayTotalMl: Double,
        goalMl: Double,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        WaterTrackerDataSections.hydrationStreak(
            allEntries: allEntries,
            todayTotalMl: todayTotalMl,
            goalMl: goalMl,
            now: now,
            calendar: calendar
        )
    }

    static func timeOfDayBreakdown(todayEntries: [WaterEntry], calendar: Calendar = .current) -> [TimeBlock] {
        WaterTrackerDataSections.timeOfDayBreakdown(todayEntries: todayEntries, calendar: calendar)
    }

    static func heroCard(todayTotalMl: Double, goalMl: Double, progress: Double) -> some View {
        WaterTrackerCardSections.heroCard(todayTotalMl: todayTotalMl, goalMl: goalMl, progress: progress)
    }

    static func quickAddCard(
        customMl: Binding<String>,
        isMlFocused: FocusState<Bool>.Binding,
        onAdd: @escaping (Double) -> Void
    ) -> some View {
        WaterTrackerCardSections.quickAddCard(customMl: customMl, isMlFocused: isMlFocused, onAdd: onAdd)
    }

    static func statsCard(
        timeRange: DetailTimeRange,
        stats: (avg: Double, daysMetGoal: Int, totalDays: Int),
        hydrationStreak: Int
    ) -> some View {
        WaterTrackerCardSections.statsCard(timeRange: timeRange, stats: stats, hydrationStreak: hydrationStreak)
    }

    static func streakCard(hydrationStreak: Int) -> some View {
        WaterTrackerCardSections.streakCard(hydrationStreak: hydrationStreak)
    }

    static func timeOfDayCard(blocks: [TimeBlock]) -> some View {
        WaterTrackerCardSections.timeOfDayCard(blocks: blocks)
    }

    static func chartCard(
        timeRange: DetailTimeRange,
        totals: [(date: Date, ml: Double)],
        goalMl: Double,
        onSelectRange: @escaping (DetailTimeRange) -> Void
    ) -> some View {
        WaterTrackerCardSections.chartCard(
            timeRange: timeRange,
            totals: totals,
            goalMl: goalMl,
            onSelectRange: onSelectRange
        )
    }

    static func todayLogCard(todayEntries: [WaterEntry]) -> some View {
        WaterTrackerCardSections.todayLogCard(todayEntries: todayEntries)
    }
}
