import SwiftUI

enum HeartRateDetailSections {
    struct Metrics {
        let averageResting: Double?
        let lowestResting: Double?
        let highestResting: Double?
        let averageHRV: Double?
        let restingTrend: Double?
        let thisWeekAvgResting: Double
        let lastWeekAvgResting: Double
        let restingChartDomain: ClosedRange<Double>
        let rangeChartDomain: ClosedRange<Double>
        let hrvChartDomain: ClosedRange<Double>

        static func make(
            dailyRestingHR: [(date: Date, bpm: Double)],
            dailyHRRange: [(date: Date, min: Double, max: Double)],
            dailyHRV: [(date: Date, ms: Double)]
        ) -> Metrics {
            let averageResting: Double? = dailyRestingHR.isEmpty ? nil
                : dailyRestingHR.map(\.bpm).reduce(0, +) / Double(dailyRestingHR.count)
            let restingTrend: Double? = {
                guard dailyRestingHR.count >= 3,
                      let first = dailyRestingHR.first?.bpm,
                      let last = dailyRestingHR.last?.bpm else { return nil }
                return last - first
            }()
            let calendar = Calendar.current
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
            let prevStart = calendar.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart
            let thisWeek = dailyRestingHR.filter { $0.date >= weekStart }
            let lastWeek = dailyRestingHR.filter { $0.date >= prevStart && $0.date < weekStart }
            let thisWeekAvg = thisWeek.isEmpty ? 0 : thisWeek.map(\.bpm).reduce(0, +) / Double(thisWeek.count)
            let lastWeekAvg = lastWeek.isEmpty ? 0 : lastWeek.map(\.bpm).reduce(0, +) / Double(lastWeek.count)

            return Metrics(
                averageResting: averageResting,
                lowestResting: dailyRestingHR.map(\.bpm).min(),
                highestResting: dailyRestingHR.map(\.bpm).max(),
                averageHRV: dailyHRV.isEmpty ? nil : dailyHRV.map(\.ms).reduce(0, +) / Double(dailyHRV.count),
                restingTrend: restingTrend,
                thisWeekAvgResting: thisWeekAvg,
                lastWeekAvgResting: lastWeekAvg,
                restingChartDomain: chartDomain(values: dailyRestingHR.map(\.bpm), default: 40...100, minPadding: 2),
                rangeChartDomain: {
                    let mins = dailyHRRange.map(\.min)
                    let maxs = dailyHRRange.map(\.max)
                    guard let lo = mins.min(), let hi = maxs.max() else { return 40...180 }
                    let padding = max(5, (hi - lo) * 0.1)
                    return (lo - padding)...(hi + padding)
                }(),
                hrvChartDomain: chartDomain(values: dailyHRV.map(\.ms), default: 0...100, minPadding: 5)
            )
        }

        private static func chartDomain(
            values: [Double],
            default defaultRange: ClosedRange<Double>,
            minPadding: Double
        ) -> ClosedRange<Double> {
            guard let minVal = values.min(), let maxVal = values.max() else { return defaultRange }
            let padding = max(minPadding, (maxVal - minVal) * 0.2)
            return (minVal - padding)...(maxVal + padding)
        }
    }

    static func heroCard(
        todayResting: Double?,
        todayStats: (min: Double, max: Double, avg: Double)?,
        todayHRV: Double?
    ) -> some View {
        HeartRateDetailHeroSections.heroCard(
            todayResting: todayResting,
            todayStats: todayStats,
            todayHRV: todayHRV
        )
    }

    static func zonesCard(stats: (min: Double, max: Double, avg: Double)) -> some View {
        HeartRateDetailHeroSections.zonesCard(stats: stats)
    }

    static func restingTrendCard(
        dailyRestingHR: [(date: Date, bpm: Double)],
        isLoading: Bool,
        metrics: Metrics
    ) -> some View {
        HeartRateDetailChartSections.restingTrendCard(
            dailyRestingHR: dailyRestingHR,
            isLoading: isLoading,
            metrics: metrics
        )
    }

    static func hrRangeCard(
        dailyHRRange: [(date: Date, min: Double, max: Double)],
        metrics: Metrics
    ) -> some View {
        HeartRateDetailChartSections.hrRangeCard(dailyHRRange: dailyHRRange, metrics: metrics)
    }

    static func hrvCard(dailyHRV: [(date: Date, ms: Double)], metrics: Metrics) -> some View {
        HeartRateDetailChartSections.hrvCard(dailyHRV: dailyHRV, metrics: metrics)
    }

    static func weeklyComparisonCard(metrics: Metrics) -> some View {
        HeartRateDetailChartSections.weeklyComparisonCard(metrics: metrics)
    }

    static func statsCard(
        todayResting: Double?,
        metrics: Metrics,
        dayCount: Int
    ) -> some View {
        HeartRateDetailChartSections.statsCard(
            todayResting: todayResting,
            metrics: metrics,
            dayCount: dayCount
        )
    }
}
