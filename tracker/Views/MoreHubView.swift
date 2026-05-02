import SwiftUI

struct MoreHubView: View {
    var body: some View {
        List {
            Section("Library") {
                NavigationLink { ExerciseLibraryView() } label: {
                    hubRow(icon: "books.vertical", color: .blue, title: "Exercise Library", subtitle: "All your exercises")
                }
                NavigationLink { AchievementsView() } label: {
                    hubRow(icon: "medal", color: .yellow, title: "Achievements", subtitle: "Badges and milestones")
                }
            }

            Section("Calculators") {
                NavigationLink { PlateCalculatorView() } label: {
                    hubRow(icon: "circle.grid.cross", color: .orange, title: "Plate Calculator", subtitle: "Barbell plate loading")
                }
                NavigationLink { OneRepMaxView() } label: {
                    hubRow(icon: "function", color: .teal, title: "1RM Calculator", subtitle: "Estimated one-rep max")
                }
            }

            Section("Timers") {
                NavigationLink { WorkoutTimerView() } label: {
                    hubRow(icon: "timer", color: .red, title: "Workout Timers", subtitle: "EMOM, AMRAP, and Tabata")
                }
            }
        }
        .navigationTitle("More")
    }
}
