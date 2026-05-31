import SwiftUI
import SwiftData

/// Holds SwiftData `@Query` properties for an active workout session.
struct WorkoutDetailQueryContainer: View {
    @Query(filter: #Predicate<Exercise> { $0.workout?.isTemplate == false })
    private var allExercises: [Exercise]
    @Query private var settingsArray: [UserSettings]
    @Query(sort: \TrainingBlock.startDate, order: .reverse)
    private var trainingBlocks: [TrainingBlock]

    let workout: Workout

    var body: some View {
        WorkoutDetailScreen(
            workout: workout,
            allExercises: allExercises,
            settingsArray: settingsArray,
            trainingBlocks: trainingBlocks
        )
    }
}
