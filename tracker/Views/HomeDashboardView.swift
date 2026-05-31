import SwiftUI
import SwiftData

struct HomeDashboardView: View {
    var body: some View {
        HomeDashboardQueryContainer()
    }
}

#Preview {
    NavigationStack { HomeDashboardView() }
        .modelContainer(for: Workout.self, inMemory: true)
}
