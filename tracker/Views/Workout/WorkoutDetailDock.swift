import SwiftUI
import SwiftData

enum WorkoutDetailDock {
    static func activeExercise(in workout: Workout) -> Exercise? {
        guard !workout.exercises.isEmpty else { return nil }
        let ordered = WorkoutDetailExerciseListSection.sortedExercises(in: workout)
        return ordered.last(where: { !$0.sets.isEmpty }) ?? ordered.first
    }

    static func lastWorkingSet(for exercise: Exercise) -> ExerciseSet? {
        exercise.sets.last(where: { !$0.isWarmUp }) ?? exercise.sets.last
    }

    static func suggestion(for exercise: Exercise, allExercises: [Exercise]) -> SuggestedSet? {
        if let last = lastWorkingSet(for: exercise), last.isCardio { return nil }
        let history = allExercises.filter { $0.name == exercise.name }
        return SuggestedSetEngine.suggestNextSet(for: exercise, history: history)
    }

    static func quickAddSet(
        for exercise: Exercise,
        allExercises: [Exercise],
        in modelContext: ModelContext
    ) {
        if let last = lastWorkingSet(for: exercise), last.isCardio {
            replicateSet(template: last, into: exercise, in: modelContext)
            return
        }
        let history = allExercises.filter { $0.name == exercise.name }
        guard let suggestion = SuggestedSetEngine.suggestNextSet(for: exercise, history: history)
        else { return }
        let newSet = ExerciseSet(
            reps: suggestion.reps,
            weight: suggestion.weight,
            isWarmUp: suggestion.isWarmUp,
            exercise: exercise
        )
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            modelContext.insert(newSet)
            exercise.sets.append(newSet)
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func replicateSet(
        template: ExerciseSet,
        into exercise: Exercise,
        in modelContext: ModelContext
    ) {
        let newSet = ExerciseSet(
            reps: template.reps,
            weight: template.weight,
            distance: template.distance,
            durationSeconds: template.durationSeconds,
            exercise: exercise
        )
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            modelContext.insert(newSet)
            exercise.sets.append(newSet)
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

struct WorkoutDetailDockBar: View {
    let workout: Workout
    let weightUnit: WeightUnit
    let allExercises: [Exercise]
    let onQuickAddSet: (Exercise) -> Void

    var body: some View {
        if let active = WorkoutDetailDock.activeExercise(in: workout),
           !workout.isFinished,
           !workout.isTemplate {
            GymDockView(
                exercise: active,
                lastSet: WorkoutDetailDock.lastWorkingSet(for: active),
                suggestion: WorkoutDetailDock.suggestion(for: active, allExercises: allExercises),
                weightUnitLabel: weightUnit == .kg ? "km" : "mi",
                onAddSet: { onQuickAddSet(active) }
            )
        }
    }
}
