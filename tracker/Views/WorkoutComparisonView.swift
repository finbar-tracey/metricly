import SwiftUI
import SwiftData

struct WorkoutComparisonView: View {
    @Query(filter: #Predicate<Workout> { !$0.isTemplate && $0.endTime != nil }, sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]
    @Environment(\.weightUnit) private var weightUnit

    @State private var leftWorkout: Workout?
    @State private var rightWorkout: Workout?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                WorkoutComparisonSections.pickerCard(
                    workouts: workouts,
                    leftWorkout: $leftWorkout,
                    rightWorkout: $rightWorkout
                )

                if let left = leftWorkout, let right = rightWorkout {
                    WorkoutComparisonSections.comparisonHeroCard(left: left, right: right, weightUnit: weightUnit)
                    WorkoutComparisonSections.summaryCard(left: left, right: right, weightUnit: weightUnit)
                    WorkoutComparisonSections.exerciseComparisonCard(left: left, right: right, weightUnit: weightUnit)
                } else {
                    WorkoutComparisonSections.emptyStateCard()
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Compare")
        .navigationBarTitleDisplayMode(.inline)
    }
}
