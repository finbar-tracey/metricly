import SwiftUI

enum StepsDetailSections {

    static let stepGoal: Double = StepsDetailHeroSections.stepGoal
    typealias Metrics = StepsDetailHeroSections.Metrics

    static func heroCard(
        todaySteps: Double,
        todayDistance: Double,
        todayEnergy: Double,
        distanceUnit: DistanceUnit,
        stepGoal: Double = stepGoal
    ) -> some View {
        StepsDetailHeroSections.heroCard(
            todaySteps: todaySteps,
            todayDistance: todayDistance,
            todayEnergy: todayEnergy,
            distanceUnit: distanceUnit,
            stepGoal: stepGoal
        )
    }

    static func trendCard(
        chartSteps: [(date: Date, steps: Double)],
        stepGoal: Double = stepGoal
    ) -> some View {
        StepsDetailChartSections.trendCard(chartSteps: chartSteps, stepGoal: stepGoal)
    }

    static func hourlyCard(hourlySteps: [(hour: Int, steps: Double)]) -> some View {
        StepsDetailChartSections.hourlyCard(hourlySteps: hourlySteps)
    }

    static func weeklyComparisonCard(metrics: Metrics) -> some View {
        StepsDetailChartSections.weeklyComparisonCard(metrics: metrics)
    }

    @ViewBuilder
    static func distanceTrendCard(
        dailyDistance: [(date: Date, km: Double)],
        dayCount: Int,
        distanceUnit: DistanceUnit
    ) -> some View {
        StepsDetailChartSections.distanceTrendCard(
            dailyDistance: dailyDistance,
            dayCount: dayCount,
            distanceUnit: distanceUnit
        )
    }

    static func streakCard(streak: Int, stepGoal: Double = stepGoal) -> some View {
        StepsDetailChartSections.streakCard(streak: streak, stepGoal: stepGoal)
    }

    static func statsCard(
        todaySteps: Double,
        metrics: Metrics,
        dailySteps: [(date: Date, steps: Double)],
        dailyDistance: [(date: Date, km: Double)]
    ) -> some View {
        StepsDetailChartSections.statsCard(
            todaySteps: todaySteps,
            metrics: metrics,
            dailySteps: dailySteps,
            dailyDistance: dailyDistance
        )
    }
}
