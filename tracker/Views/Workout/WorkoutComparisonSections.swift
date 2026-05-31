import SwiftUI
import SwiftData

enum WorkoutComparisonSections {

    typealias ExerciseMatch = WorkoutComparisonDiffSection.ExerciseMatch

    static func pickerCard(
        workouts: [Workout],
        leftWorkout: Binding<Workout?>,
        rightWorkout: Binding<Workout?>
    ) -> some View {
        WorkoutComparisonSummarySection.pickerCard(
            workouts: workouts,
            leftWorkout: leftWorkout,
            rightWorkout: rightWorkout
        )
    }

    static func comparisonHeroCard(left: Workout, right: Workout, weightUnit: WeightUnit) -> some View {
        WorkoutComparisonSummarySection.comparisonHeroCard(left: left, right: right, weightUnit: weightUnit)
    }

    static func summaryCard(left: Workout, right: Workout, weightUnit: WeightUnit) -> some View {
        WorkoutComparisonSummarySection.summaryCard(left: left, right: right, weightUnit: weightUnit)
    }

    static func exerciseComparisonCard(left: Workout, right: Workout, weightUnit: WeightUnit) -> some View {
        WorkoutComparisonDiffSection.exerciseComparisonCard(left: left, right: right, weightUnit: weightUnit)
    }

    static func emptyStateCard() -> some View {
        WorkoutComparisonSummarySection.emptyStateCard()
    }
}
