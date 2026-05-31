import SwiftUI

extension ContentView {
    var moreTab: some View {
        NavigationStack {
            MoreHubView()
                .navigationDestination(for: String.self) { exerciseName in
                    ExerciseHistoryView(exerciseName: exerciseName)
                }
        }
    }
}
