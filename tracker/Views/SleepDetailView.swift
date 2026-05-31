import SwiftUI

struct SleepDetailView: View {
    @Environment(\.appServices) private var appServices
    @State private var dailySleep: [(date: Date, minutes: Double)] = []
    @State private var todaySleep: (totalMinutes: Double, inBed: Date?, wakeUp: Date?, stages: [SleepStage]) = (0, nil, nil, [])
    @State private var detailedSleep: [DailySleepDetail] = []
    @State private var timeRange: DetailTimeRange = .week
    @State private var isLoading = true

    private var dayCount: Int { timeRange.dayCount }

    private var chartSleep: [(date: Date, minutes: Double)] {
        SleepEngine.chartSleep(dailySleep: dailySleep, dayCount: dayCount)
    }

    private var thisWeekAvg: Double { SleepEngine.thisWeekAverage(dailySleep: dailySleep) }
    private var lastWeekAvg: Double { SleepEngine.lastWeekAverage(dailySleep: dailySleep) }
    private var averageSleep: Double { SleepEngine.averageSleep(dailySleep: dailySleep) }

    var body: some View {
        MetricDetailScaffold(
            navigationTitle: "Sleep",
            isLoading: isLoading && todaySleep.totalMinutes == 0,
            isEmpty: todaySleep.totalMinutes == 0 && !isLoading,
            loadingMessage: "Loading sleep…",
            emptyIcon: "bed.double.fill",
            emptyTitle: "No Sleep Data",
            emptySubtitle: "No sleep data recorded for last night.",
            timeRange: $timeRange,
            segmentColor: .indigo,
            showRangePicker: true,
            hero: {
                SleepDetailSections.heroCard(todaySleep: todaySleep, detailedSleep: detailedSleep)
            },
            content: {
                if !todaySleep.stages.isEmpty {
                    SleepDetailSections.timelineCard(stages: todaySleep.stages)
                    SleepDetailSections.stageCardsCard(todaySleep: todaySleep)
                }
                SleepDetailSections.durationTrendCard(
                    chartSleep: chartSleep,
                    timeRange: timeRange,
                    isLoading: isLoading,
                    onSelectRange: { timeRange = $0 }
                )
                SleepDetailSections.weeklyComparisonCard(
                    thisWeekAvg: thisWeekAvg,
                    lastWeekAvg: lastWeekAvg
                )
                SleepDetailSections.consistencyCard(detailedSleep: detailedSleep)
                SleepDetailSections.sleepDebtCard(detailedSleep: detailedSleep)
                SleepDetailSections.statsCard(dailySleep: dailySleep, averageSleep: averageSleep)
            }
        )
        .task(id: timeRange) { await loadData() }
    }

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        let hk = appServices.healthDataCache
        let fetchDays = max(dayCount, 14)
        async let sleepData = hk.fetchDailySleep(days: fetchDays)
        async let todayData = hk.fetchSleep(for: .now)
        async let detailedData = hk.fetchDailySleepDetailed(days: 7)
        dailySleep = (try? await sleepData) ?? []
        todaySleep = (try? await todayData) ?? (0, nil, nil, [])
        detailedSleep = (try? await detailedData) ?? []
    }
}
