import SwiftUI
import SwiftData

/// Composes workout detail list chrome; delegates to existing `WorkoutDetail*` section views.
enum WorkoutDetailScreenSections {

    static func planAdjustmentsForWorkout(_ workout: Workout) -> TodayPlan? {
        guard let plan = TodayPlanStore.load(),
              !plan.alreadyTrainedToday,
              Calendar.current.isDateInToday(workout.date),
              workout.name.localizedCaseInsensitiveCompare(plan.recommendedName) == .orderedSame,
              plan.intensity != .rest
        else { return nil }
        return plan
    }

    @ViewBuilder
    static func activeWorkoutList(
        workout: Workout,
        weightUnit: WeightUnit,
        allExercises: [Exercise],
        elapsedTime: String,
        planAdjustments: TodayPlan?,
        planAdjustmentsDismissed: Bool,
        trainingBlocks: [TrainingBlock],
        dismissedSubstitutions: Set<PersistentIdentifier>,
        sortedExercises: [Exercise],
        suggestions: [String],
        newExerciseName: Binding<String>,
        newExerciseCategory: Binding<MuscleGroup>,
        showingSuggestions: Binding<Bool>,
        exerciseToDelete: Binding<Exercise?>,
        linkingSupersetFor: Binding<Exercise?>,
        onDismissPlan: @escaping () -> Void,
        onApplyPlan: @escaping (TodayPlan) -> Void,
        onSwapSubstitution: @escaping (TodayPlanApply.SubstitutionSuggestion) -> Void,
        onKeepSubstitution: @escaping (PersistentIdentifier) -> Void,
        onAddExercise: @escaping () -> Void,
        onAutoSelectCategory: @escaping () -> Void,
        onMoveExercises: @escaping (IndexSet, Int) -> Void,
        onUnlinkSuperset: @escaping (Exercise) -> Void
    ) -> some View {
        List {
            if !workout.isTemplate {
                Section {
                    WorkoutHeroCard(
                        workout: workout,
                        weightUnit: weightUnit,
                        progressFraction: WorkoutDetailProgress.progressFraction(in: workout),
                        progressRatio: WorkoutDetailProgress.progressRatio(in: workout),
                        totalWorkingSets: WorkoutDetailProgress.totalWorkingSets(in: workout),
                        elapsedTime: elapsedTime
                    )
                    .listRowBackground(Color.clear)
                    .listRowInsets(.init(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                WorkoutDetailPlanSection(
                    workout: workout,
                    planAdjustments: planAdjustments,
                    planAdjustmentsDismissed: planAdjustmentsDismissed,
                    trainingBlocks: trainingBlocks,
                    dismissedSubstitutions: dismissedSubstitutions,
                    onDismissPlan: onDismissPlan,
                    onApplyPlan: onApplyPlan,
                    onSwapSubstitution: onSwapSubstitution,
                    onKeepSubstitution: onKeepSubstitution
                )
            }

            WorkoutDetailExerciseListSection(
                workout: workout,
                weightUnit: weightUnit,
                allExercises: allExercises,
                sortedExercises: sortedExercises,
                suggestions: suggestions,
                newExerciseName: newExerciseName,
                newExerciseCategory: newExerciseCategory,
                showingSuggestions: showingSuggestions,
                exerciseToDelete: exerciseToDelete,
                linkingSupersetFor: linkingSupersetFor,
                onAddExercise: onAddExercise,
                onAutoSelectCategory: onAutoSelectCategory,
                onMoveExercises: onMoveExercises,
                onUnlinkSuperset: onUnlinkSuperset
            )
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
    }

    @ViewBuilder
    static func bottomDock(
        workout: Workout,
        weightUnit: WeightUnit,
        allExercises: [Exercise],
        onQuickAddSet: @escaping (Exercise) -> Void
    ) -> some View {
        WorkoutDetailDockBar(
            workout: workout,
            weightUnit: weightUnit,
            allExercises: allExercises,
            onQuickAddSet: onQuickAddSet
        )
    }
}
