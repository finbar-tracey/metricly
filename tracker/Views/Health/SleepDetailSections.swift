import SwiftUI

enum SleepDetailSections {

    static func heroCard(
        todaySleep: (totalMinutes: Double, inBed: Date?, wakeUp: Date?, stages: [SleepStage]),
        detailedSleep: [DailySleepDetail]
    ) -> some View {
        SleepDetailHeroSections.heroCard(todaySleep: todaySleep, detailedSleep: detailedSleep)
    }

    static func timelineCard(stages: [SleepStage]) -> some View {
        SleepDetailChartSections.timelineCard(stages: stages)
    }

    static func stageCardsCard(
        todaySleep: (totalMinutes: Double, inBed: Date?, wakeUp: Date?, stages: [SleepStage])
    ) -> some View {
        SleepDetailChartSections.stageCardsCard(todaySleep: todaySleep)
    }

    static func durationTrendCard(
        chartSleep: [(date: Date, minutes: Double)],
        timeRange: DetailTimeRange,
        isLoading: Bool,
        onSelectRange: @escaping (DetailTimeRange) -> Void
    ) -> some View {
        SleepDetailChartSections.durationTrendCard(
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
        SleepDetailChartSections.weeklyComparisonCard(thisWeekAvg: thisWeekAvg, lastWeekAvg: lastWeekAvg)
    }

    @ViewBuilder
    static func consistencyCard(detailedSleep: [DailySleepDetail]) -> some View {
        SleepDetailChartSections.consistencyCard(detailedSleep: detailedSleep)
    }

    @ViewBuilder
    static func sleepDebtCard(detailedSleep: [DailySleepDetail]) -> some View {
        SleepDetailChartSections.sleepDebtCard(detailedSleep: detailedSleep)
    }

    static func statsCard(
        dailySleep: [(date: Date, minutes: Double)],
        averageSleep: Double
    ) -> some View {
        SleepDetailChartSections.statsCard(dailySleep: dailySleep, averageSleep: averageSleep)
    }
}
