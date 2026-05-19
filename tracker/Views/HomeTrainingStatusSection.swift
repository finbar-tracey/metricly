import SwiftUI

/// Compact training-status card on the home dashboard: weekly goal,
/// streak, suggested workout type chip, average rating.
struct HomeTrainingStatusSection: View {
    let weeklyGoal: Int
    let activitiesThisWeek: Int
    let currentStreak: Int
    let suggestedWorkoutType: String
    let averageRating: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Training", icon: "dumbbell.fill", color: .accentColor)

            VStack(spacing: 0) {
                if weeklyGoal > 0 {
                    let weekProgress = min(1.0, Double(activitiesThisWeek) / Double(weeklyGoal))
                    let weekDone = activitiesThisWeek >= weeklyGoal
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "target").foregroundStyle(weekDone ? Color.green : Color.accentColor)
                                Text("\(activitiesThisWeek)/\(weeklyGoal) workouts this week").font(.subheadline)
                            }
                            Spacer()
                            if weekDone {
                                Text("DONE")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .tracking(0.6)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 9).padding(.vertical, 4)
                                    .background(
                                        LinearGradient(
                                            colors: [.green, AppTheme.Signal.actionGreen],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        ),
                                        in: Capsule()
                                    )
                                    .shadow(color: .green.opacity(0.4), radius: 5, y: 2)
                            }
                        }
                        GradientProgressBar(value: weekProgress, color: weekDone ? .green : .accentColor, height: 10)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                }

                Divider().padding(.leading, 16)

                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(currentStreak >= 3 ? .orange : .secondary)
                        Text("\(currentStreak) day streak")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    Spacer()
                    NavigationLink { SmartSuggestionsView() } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "brain.head.profile").font(.caption.weight(.semibold))
                            Text(suggestedWorkoutType).font(.caption.weight(.semibold))
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.18), Color.purple.opacity(0.10)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            in: Capsule()
                        )
                        .overlay(Capsule().stroke(Color.purple.opacity(0.20), lineWidth: 0.5))
                        .foregroundStyle(.purple)
                    }
                    .buttonStyle(.pressableCard)
                }
                .padding(.horizontal, 16).padding(.vertical, 14)

                if let avgRating = averageRating {
                    Divider().padding(.leading, 16)
                    HStack(spacing: 5) {
                        Image(systemName: "star.fill").foregroundStyle(.yellow)
                        Text(String(format: "%.1f", avgRating)).font(.subheadline.weight(.medium))
                        Text("avg rating this week").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
            )
        }
        .appCard()
    }
}
