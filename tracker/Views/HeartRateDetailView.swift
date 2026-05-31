import SwiftUI

struct HeartRateDetailView: View {
    @Environment(\.appServices) private var appServices
    @State private var dailyRestingHR: [(date: Date, bpm: Double)] = []
    @State private var dailyHRRange: [(date: Date, min: Double, max: Double)] = []
    @State private var dailyHRV: [(date: Date, ms: Double)] = []
    @State private var todayStats: (min: Double, max: Double, avg: Double)?
    @State private var todayResting: Double?
    @State private var todayHRV: Double?
    @State private var timeRange: DetailTimeRange = .month
    @State private var isLoading = true

    private var dayCount: Int { timeRange.dayCount }

    private var metrics: HeartRateDetailSections.Metrics {
        HeartRateDetailSections.Metrics.make(
            dailyRestingHR: dailyRestingHR,
            dailyHRRange: dailyHRRange,
            dailyHRV: dailyHRV
        )
    }

    private var heartRateEmpty: Bool {
        !isLoading && todayStats == nil && dailyRestingHR.isEmpty
    }

    var body: some View {
        MetricDetailScaffold(
            navigationTitle: "Heart Rate",
            isLoading: isLoading && todayStats == nil,
            isEmpty: heartRateEmpty,
            loadingMessage: "Loading heart rate…",
            emptyIcon: "heart.fill",
            emptyTitle: "No Heart Rate Data",
            emptySubtitle: "Connect Health in Settings to see resting HR and HRV.",
            timeRange: $timeRange,
            segmentColor: Color(red: 0.88, green: 0.15, blue: 0.25),
            showRangePicker: true,
            hero: {
                HeartRateDetailSections.heroCard(
                    todayResting: todayResting,
                    todayStats: todayStats,
                    todayHRV: todayHRV
                )
            },
            content: {
                if let stats = todayStats {
                    HeartRateDetailSections.zonesCard(stats: stats)
                }
                HeartRateDetailSections.restingTrendCard(
                    dailyRestingHR: dailyRestingHR,
                    isLoading: isLoading,
                    metrics: metrics
                )
                if !dailyHRRange.isEmpty {
                    HeartRateDetailSections.hrRangeCard(dailyHRRange: dailyHRRange, metrics: metrics)
                }
                if !dailyHRV.isEmpty {
                    HeartRateDetailSections.hrvCard(dailyHRV: dailyHRV, metrics: metrics)
                }
                if metrics.lastWeekAvgResting > 0 {
                    HeartRateDetailSections.weeklyComparisonCard(metrics: metrics)
                }
                HeartRateDetailSections.statsCard(
                    todayResting: todayResting,
                    metrics: metrics,
                    dayCount: dailyRestingHR.count
                )
            }
        )
        .task(id: timeRange) {
            await loadData()
        }
    }

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        let hk = appServices.healthDataCache
        let fetchDays = max(dayCount, 14)
        async let hrData = hk.fetchDailyRestingHeartRate(days: fetchDays)
        async let rangeData = hk.fetchDailyHeartRateRange(days: min(dayCount, 30))
        async let hrvData = hk.fetchDailyHRV(days: fetchDays)
        async let statsData = hk.fetchHeartRateStats(for: .now)
        async let restingData = hk.fetchRestingHeartRate(for: .now)
        async let hrvToday = hk.fetchHRV(for: .now)
        dailyRestingHR = (try? await hrData) ?? []
        dailyHRRange = (try? await rangeData) ?? []
        dailyHRV = (try? await hrvData) ?? []
        todayStats = try? await statsData
        todayResting = try? await restingData
        todayHRV = try? await hrvToday
    }
}
