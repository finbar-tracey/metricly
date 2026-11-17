import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    let workout: Workout

    var body: some View {
        WorkoutDetailQueryContainer(workout: workout)
            // A session in progress owns the screen — the tab bar goes away
            // until it's finished. Templates also have no endTime but aren't
            // sessions, so they keep the tab bar. Step 9 restyles what's underneath.
            .hidesMetriclyTabBar(!workout.isTemplate && !workout.isFinished)
    }
}
