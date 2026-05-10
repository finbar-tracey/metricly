import SwiftUI

/// Root container — Gym + Cardio tabs. Both child views handle their own
/// pre-workout vs active states internally, so the root doesn't need to
/// override the layout when a session starts. (Earlier the root replaced
/// the tabs with a dead-end heart-rate display, locking the user out of
/// Finish Workout.)
struct WatchRootView: View {
    var body: some View {
        TabView {
            NavigationStack {
                WatchGymView()
            }
            .tabItem { Label("Gym", systemImage: "dumbbell.fill") }

            NavigationStack {
                WatchCardioStartView()
            }
            .tabItem { Label("Cardio", systemImage: "figure.run") }
        }
    }
}
