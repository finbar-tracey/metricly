import SwiftUI

/// All-time records, volume tiles, pace trend chart, and empty state for Personal Bests.
enum CardioBestsRecordsSection {

    static func allTimeSection(
        group: CardioBestsView.ActivityGroup,
        longestSession: CardioSession?,
        fastestPaceSession: CardioSession?,
        fastestSplit: (paceSecPerUnit: Double, session: CardioSession)?,
        longestDuration: CardioSession?,
        mostElevation: CardioSession?,
        mostCaloriesSession: CardioSession?,
        bestAerobicSession: CardioSession?,
        useKm: Bool
    ) -> some View {
        CardioBestsPRSection.allTimeSection(
            group: group,
            longestSession: longestSession,
            fastestPaceSession: fastestPaceSession,
            fastestSplit: fastestSplit,
            longestDuration: longestDuration,
            mostElevation: mostElevation,
            mostCaloriesSession: mostCaloriesSession,
            bestAerobicSession: bestAerobicSession,
            useKm: useKm
        )
    }

    static func volumeSection(
        group: CardioBestsView.ActivityGroup,
        bestWeek: CardioBestsView.WeekRecord?,
        bestMonth: CardioBestsView.MonthRecord?,
        busiestWeek: CardioBestsView.WeekRecord?,
        negativeSplitCount: Int,
        distUnit: DistanceUnit
    ) -> some View {
        CardioBestsBenchmarkSection.volumeSection(
            group: group,
            bestWeek: bestWeek,
            bestMonth: bestMonth,
            busiestWeek: busiestWeek,
            negativeSplitCount: negativeSplitCount,
            distUnit: distUnit
        )
    }

    static func trendSection(
        group: CardioBestsView.ActivityGroup,
        benchmarks: [CardioBestsView.Benchmark],
        sessions: [CardioSession],
        activeBenchmark: CardioBestsView.Benchmark?,
        trendPoints: [CardioBestsView.PaceTrendPoint],
        chartBenchmark: Binding<CardioBestsView.Benchmark?>,
        useKm: Bool
    ) -> some View {
        CardioBestsBenchmarkSection.trendSection(
            group: group,
            benchmarks: benchmarks,
            sessions: sessions,
            activeBenchmark: activeBenchmark,
            trendPoints: trendPoints,
            chartBenchmark: chartBenchmark,
            useKm: useKm
        )
    }

    static func emptyState(group: CardioBestsView.ActivityGroup) -> some View {
        CardioBestsBenchmarkSection.emptyState(group: group)
    }
}
