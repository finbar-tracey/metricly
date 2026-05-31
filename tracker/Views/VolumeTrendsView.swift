import SwiftUI
import SwiftData

struct VolumeTrendsView: View {
    @Query(filter: #Predicate<Workout> { !$0.isTemplate && $0.endTime != nil },
           sort: \Workout.date)
    private var workouts: [Workout]
    @Environment(\.weightUnit) private var unit

    @State private var timeRange: VolumeTrendPeriod = .weekly

    private var volumeData: [VolumePoint] {
        VolumeTrendsEngine.volumeData(workouts: workouts, period: timeRange)
    }

    private var muscleVolumeData: [(MuscleGroup, Double)] {
        VolumeTrendsEngine.muscleVolumeByGroup(workouts: workouts)
    }

    private var totalVolumeThisWeek: Double {
        VolumeTrendsEngine.totalVolumeThisWeek(workouts: workouts)
    }

    private var totalVolumeLastWeek: Double {
        VolumeTrendsEngine.totalVolumeLastWeek(workouts: workouts)
    }

    private var volumeChange: Double {
        VolumeTrendsEngine.volumeChangePercent(thisWeek: totalVolumeThisWeek, lastWeek: totalVolumeLastWeek)
    }

    private var workoutsThisWeek: Int {
        VolumeTrendsEngine.workoutsThisWeek(workouts: workouts)
    }

    private func formatVolume(_ volume: Double) -> String {
        VolumeTrendsEngine.formatVolume(volume, unit: unit)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                VolumeTrendsSections.heroCard(
                    totalVolumeThisWeek: totalVolumeThisWeek,
                    totalVolumeLastWeek: totalVolumeLastWeek,
                    volumeChange: volumeChange,
                    workoutsThisWeek: workoutsThisWeek,
                    formatVolume: formatVolume
                )
                VolumeTrendsSections.volumeChartCard(
                    timeRange: $timeRange,
                    volumeData: volumeData,
                    unit: unit
                )
                if !muscleVolumeData.isEmpty {
                    VolumeTrendsSections.muscleBreakdownCard(
                        muscleVolumeData: muscleVolumeData,
                        formatVolume: formatVolume
                    )
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Volume Trends")
    }
}

#Preview {
    NavigationStack { VolumeTrendsView() }
        .modelContainer(for: Workout.self, inMemory: true)
}
