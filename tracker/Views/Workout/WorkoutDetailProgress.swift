import SwiftUI
import SwiftData

enum WorkoutDetailProgress {
    static func completedExercises(in workout: Workout) -> Int {
        workout.exercises.reduce(0) { total, ex in
            total + (ex.sets.contains { !$0.isWarmUp && $0.weight > 0 } ? 1 : 0)
        }
    }

    static func totalWorkingSets(in workout: Workout) -> Int {
        workout.exercises.flatMap(\.sets).filter { !$0.isWarmUp }.count
    }

    static func progressFraction(in workout: Workout) -> String {
        let done = completedExercises(in: workout)
        return "\(done)/\(workout.exercises.count)"
    }

    static func progressRatio(in workout: Workout) -> Double {
        guard !workout.exercises.isEmpty else { return 0 }
        return Double(completedExercises(in: workout)) / Double(workout.exercises.count)
    }

    static func lastSessionTopSet(for exercise: Exercise, allExercises: [Exercise]) -> ExerciseSet? {
        let prior = allExercises
            .filter { other in
                other.persistentModelID != exercise.persistentModelID
                && other.name.lowercased() == exercise.name.lowercased()
                && !other.sets.isEmpty
                && (other.workout?.endTime != nil)
            }
            .sorted { ($0.workout?.date ?? .distantPast) > ($1.workout?.date ?? .distantPast) }
        guard let last = prior.first else { return nil }
        let working = last.sets.filter { !$0.isWarmUp && $0.weight > 0 }
        return working.max(by: { $0.weight < $1.weight })
    }

    static func progressBadge(
        for exercise: Exercise,
        allExercises: [Exercise],
        weightUnit: WeightUnit
    ) -> WorkoutExerciseRow.Badge? {
        let working = exercise.sets.filter { !$0.isWarmUp && $0.weight > 0 }
        guard let currentTop = working.max(by: { $0.weight < $1.weight }) else { return nil }
        guard let lastTop = lastSessionTopSet(for: exercise, allExercises: allExercises) else {
            return .init(text: "New", color: .blue)
        }
        let weightDelta = currentTop.weight - lastTop.weight
        if weightDelta >= 0.1 {
            return .init(text: "↑ \(weightUnit.formatShort(weightDelta))", color: .green)
        }
        if weightDelta <= -0.1 {
            return .init(text: "↓ \(weightUnit.formatShort(abs(weightDelta)))", color: .orange)
        }
        let currentRepsAtTop = working.filter { abs($0.weight - currentTop.weight) < 0.01 }.map(\.reps).max() ?? 0
        let lastRepsAtTop = lastTop.reps
        if currentRepsAtTop > lastRepsAtTop {
            return .init(
                text: "↑ +\(currentRepsAtTop - lastRepsAtTop) rep\(currentRepsAtTop - lastRepsAtTop == 1 ? "" : "s")",
                color: .green
            )
        }
        return nil
    }
}
