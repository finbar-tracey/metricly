import SwiftUI

struct StepsDetailView: View {
    @Environment(\.appServices) private var appServices
    @Environment(\.weightUnit) private var weightUnit
    @State private var dailySteps: [(date: Date, steps: Double)] = []
    @State private var dailyDistance: [(date: Date, km: Double)] = []
    @State private var dailyEnergy: [(date: Date, kcal: Double)] = []
    @State private var hourlySteps: [(hour: Int, steps: Double)] = []
    @State private var todaySteps: Double = 0
    @State private var todayDistance: Double = 0
    @State private var todayEnergy: Double = 0
    @State private var timeRange: DetailTimeRange = .week
    @State private var isLoading = true

    private var dayCount: Int { timeRange.dayCount }

    private var metrics: StepsDetailSections.Metrics {
        StepsDetailSections.Metrics.make(dailySteps: dailySteps)
    }

    private var chartSteps: [(date: Date, steps: Double)] {
        Array(dailySteps.suffix(dayCount))
    }

    private var stepsContentEmpty: Bool {
        !isLoading && todaySteps == 0 && dailySteps.allSatisfy { $0.steps == 0 }
    }

    var body: some View {
        MetricDetailScaffold(
            navigationTitle: "Steps",
            isLoading: isLoading && todaySteps == 0,
            isEmpty: stepsContentEmpty,
            loadingMessage: "Loading steps…",
            emptyIcon: "figure.walk",
            emptyTitle: "No Step Data",
            emptySubtitle: "Allow Health access in Settings to see your steps.",
            timeRange: $timeRange,
            segmentColor: .green,
            showRangePicker: true,
            hero: {
                StepsDetailSections.heroCard(
                    todaySteps: todaySteps,
                    todayDistance: todayDistance,
                    todayEnergy: todayEnergy,
                    distanceUnit: weightUnit.distanceUnit
                )
            },
            content: {
                StepsDetailSections.trendCard(chartSteps: chartSteps)
                if !hourlySteps.isEmpty && hourlySteps.contains(where: { $0.steps > 0 }) {
                    StepsDetailSections.hourlyCard(hourlySteps: hourlySteps)
                }
                if metrics.lastWeekAvg > 0 {
                    StepsDetailSections.weeklyComparisonCard(metrics: metrics)
                }
                StepsDetailSections.distanceTrendCard(
                    dailyDistance: dailyDistance,
                    dayCount: dayCount,
                    distanceUnit: weightUnit.distanceUnit
                )
                if metrics.currentGoalStreak > 0 {
                    StepsDetailSections.streakCard(streak: metrics.currentGoalStreak)
                }
                StepsDetailSections.statsCard(
                    todaySteps: todaySteps,
                    metrics: metrics,
                    dailySteps: dailySteps,
                    dailyDistance: dailyDistance
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
        async let stepsData = hk.fetchDailySteps(days: fetchDays)
        async let distData = hk.fetchDailyDistance(days: fetchDays)
        async let energyData = hk.fetchDailyActiveEnergy(days: fetchDays)
        async let hourlyData = hk.fetchHourlySteps(for: .now)
        async let todayStepsData = hk.fetchSteps(for: .now)
        async let todayDistData = hk.fetchDistance(for: .now)
        async let todayEnergyData = hk.fetchActiveEnergy(for: .now)
        dailySteps = (try? await stepsData) ?? []
        dailyDistance = (try? await distData) ?? []
        dailyEnergy = (try? await energyData) ?? []
        hourlySteps = (try? await hourlyData) ?? []
        todaySteps = (try? await todayStepsData) ?? 0
        todayDistance = (try? await todayDistData) ?? 0
        todayEnergy = (try? await todayEnergyData) ?? 0
    }
}
