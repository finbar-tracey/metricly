import SwiftUI

extension ContentView {
    var trainingTab: some View {
        NavigationStack {
            TrainingHubView()
                .navigationDestination(for: Workout.self) { workout in
                    WorkoutDetailView(workout: workout)
                }
                .navigationDestination(for: String.self) { exerciseName in
                    ExerciseHistoryView(exerciseName: exerciseName)
                }
        }
    }
}
