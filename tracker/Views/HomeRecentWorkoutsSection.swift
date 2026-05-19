import SwiftUI

/// Recent workouts list on the home dashboard. Empty-state has a
/// "Start Your First Workout" button that calls back to the parent
/// to present the AddWorkoutSheet.
struct HomeRecentWorkoutsSection: View {
    let workouts: [Workout]
    let onStartFirstWorkout: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Recent Workouts", icon: "clock.fill", color: .blue)

            if workouts.isEmpty {
                EmptyStateView(
                    icon: "dumbbell.fill",
                    title: "No workouts yet",
                    subtitle: "Log your first session to start seeing recovery, progression, and streak data.",
                    action: .init(label: "Start Your First Workout", perform: onStartFirstWorkout)
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(workouts.prefix(5).enumerated()), id: \.element.id) { index, workout in
                        NavigationLink(value: workout) {
                            HStack {
                                WorkoutCardView(workout: workout)
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 4)
                        }
                        .buttonStyle(.pressableCard)
                        if index < min(workouts.count, 5) - 1 { Divider().padding(.leading, 16) }
                    }
                }
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                if workouts.count > 5 {
                    NavigationLink { FullWorkoutListView() } label: {
                        HStack {
                            Text("See All Workouts").font(.subheadline.weight(.medium))
                            Spacer()
                            Text("\(workouts.count)").font(.caption.bold().monospacedDigit()).foregroundStyle(.secondary)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 13)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.pressableCard)
                }
            }
        }
        .appCard()
    }
}
