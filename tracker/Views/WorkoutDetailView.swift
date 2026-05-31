import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    let workout: Workout

    var body: some View {
        WorkoutDetailQueryContainer(workout: workout)
    }
}
