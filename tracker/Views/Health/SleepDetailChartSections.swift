import SwiftUI

enum SleepDetailChartSections {

    static func timelineCard(stages: [SleepStage]) -> some View {
        SleepDetailTrendSections.timelineCard(stages: stages)
    }

    static func stageCardsCard(
        todaySleep: (totalMinutes: Double, inBed: Date?, wakeUp: Date?, stages: [SleepStage])
    ) -> some View {
        SleepDetailTrendSections.stageCardsCard(todaySleep: todaySleep)
    }

    static func durationTrendCard(
        chartSleep: [(date: Date, minutes: Double)],
        timeRange: DetailTimeRange,
        isLoading: Bool,
        onSelectRange: @escaping (DetailTimeRange) -> Void
    ) -> some View {
        SleepDetailTrendSections.durationTrendCard(
            chartSleep: chartSleep,
            timeRange: timeRange,
            isLoading: isLoading,
            onSelectRange: onSelectRange
        )
    }

    @ViewBuilder
    static func weeklyComparisonCard(
        thisWeekAvg: Double,
        lastWeekAvg: Double
    ) -> some View {
        SleepDetailStatsSections.weeklyComparisonCard(thisWeekAvg: thisWeekAvg, lastWeekAvg: lastWeekAvg)
    }

    @ViewBuilder
    static func consistencyCard(detailedSleep: [DailySleepDetail]) -> some View {
        SleepDetailStatsSections.consistencyCard(detailedSleep: detailedSleep)
    }

    @ViewBuilder
    static func sleepDebtCard(detailedSleep: [DailySleepDetail]) -> some View {
        SleepDetailStatsSections.sleepDebtCard(detailedSleep: detailedSleep)
    }

    static func statsCard(
        dailySleep: [(date: Date, minutes: Double)],
        averageSleep: Double
    ) -> some View {
        SleepDetailStatsSections.statsCard(dailySleep: dailySleep, averageSleep: averageSleep)
    }
}
