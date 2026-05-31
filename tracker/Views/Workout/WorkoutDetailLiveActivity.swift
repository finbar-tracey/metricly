import Foundation

enum WorkoutDetailLiveActivity {

    static func startIfNeeded(for workout: Workout, activity: WorkoutActivityManager) {
        guard !workout.isFinished, !workout.isTemplate else { return }
        let manager = activity
        if !manager.isActive {
            manager.startActivity(workoutName: workout.name)
        }
        update(for: workout, activity: activity)
    }

    static func update(for workout: Workout, activity: WorkoutActivityManager) {
        let manager = activity
        let sorted = WorkoutDetailExerciseListSection.sortedExercises(in: workout)
        let totalSets = workout.exercises.reduce(0) { $0 + $1.sets.count }
        let currentExercise = sorted.last?.name ?? workout.name
        manager.updateActivity(
            exerciseCount: workout.exercises.count,
            setCount: totalSets,
            currentExercise: currentExercise
        )
    }
}
