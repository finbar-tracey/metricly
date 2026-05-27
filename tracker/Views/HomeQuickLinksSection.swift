import SwiftUI

/// Quick-access tile grid at the bottom of the home dashboard.
/// Pure navigation entry points — no state of its own.
///
/// Extracted from HomeDashboardView during the sprint-2 decomposition.
struct HomeQuickLinksSection: View {
    let inProgressWorkout: Workout?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Quick Access", icon: "bolt.circle.fill", color: .yellow)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                if let active = inProgressWorkout {
                    NavigationLink(value: active) {
                        tile(icon: "play.circle.fill", color: .orange, title: "Continue Workout")
                    }.buttonStyle(.pressableCard)
                } else {
                    NavigationLink { WorkoutScheduleView() } label: {
                        tile(icon: "calendar.badge.checkmark", color: .green, title: "Weekly Schedule")
                    }.buttonStyle(.pressableCard)
                }

                NavigationLink { ExerciseLibraryView() } label: {
                    tile(icon: "books.vertical", color: .blue, title: "Exercise Library")
                }.buttonStyle(.pressableCard)

                NavigationLink { InsightsView() } label: {
                    tile(icon: "chart.bar.fill", color: .purple, title: "Insights")
                }.buttonStyle(.pressableCard)

                NavigationLink { PersonalRecordsView() } label: {
                    tile(icon: "trophy.fill", color: .yellow, title: "Personal Records")
                }.buttonStyle(.pressableCard)

                NavigationLink { HealthDashboardView() } label: {
                    tile(icon: "heart.text.square", color: .red, title: "Health")
                }.buttonStyle(.pressableCard)
            }
        }
        .appCard()
    }

    private func tile(icon: String, color: Color, title: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.72)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                    .shadow(color: color.opacity(0.45), radius: 10, x: 0, y: 5)
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text(title)
                // Subheadline = 15pt default; .rounded design preserved
                // via the system(_:design:) overload. Scales with Dynamic Type.
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }
}
