import SwiftUI

extension ContentView {
    var homeTab: some View {
        NavigationStack {
            HomeDashboardView()
                .navigationDestination(for: Workout.self) { workout in
                    WorkoutDetailView(workout: workout)
                }
                .navigationDestination(for: String.self) { exerciseName in
                    ExerciseHistoryView(exerciseName: exerciseName)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel("Settings")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingSearch = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        .accessibilityLabel("Search")
                    }
                }
                .sheet(isPresented: $showingSearch) {
                    GlobalSearchView()
                }
        }
    }
}
