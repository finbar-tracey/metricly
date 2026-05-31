import SwiftUI

enum CardioGoalsProgressSections {

    static func weeklyProgressCard(
        distanceGoalKm: Double,
        sessionGoal: Int,
        thisWeekDistanceKm: Double,
        thisWeekSessionCount: Int,
        distanceUnit: DistanceUnit,
        distanceProgress: Double,
        sessionProgress: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeader(title: "This Week", icon: "calendar.badge.checkmark", color: .orange)

            if distanceGoalKm == 0 && sessionGoal == 0 {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.orange, AppTheme.Signal.actionOrange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                            .shadow(color: .orange.opacity(0.40), radius: 6, y: 3)
                        Image(systemName: "target")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("No goals set")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        Text("Set a weekly distance or session goal below.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [Color.orange.opacity(0.10), Color.orange.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.orange.opacity(0.20), lineWidth: 0.5)
                )
            } else {
                VStack(spacing: 16) {
                    if distanceGoalKm > 0 {
                        goalProgressRow(
                            title: "Distance",
                            icon: "ruler",
                            color: .orange,
                            current: String(format: "%.1f %@", distanceUnit.display(thisWeekDistanceKm), distanceUnit.label),
                            goal: String(format: "%.0f %@", distanceUnit.display(distanceGoalKm), distanceUnit.label),
                            progress: distanceProgress
                        )
                    }

                    if sessionGoal > 0 {
                        goalProgressRow(
                            title: "Sessions",
                            icon: "figure.run",
                            color: .blue,
                            current: "\(thisWeekSessionCount)",
                            goal: "\(sessionGoal)",
                            progress: sessionProgress
                        )
                    }
                }
            }
        }
        .appCard()
    }

    private static func goalProgressRow(
        title: String,
        icon: String,
        color: Color,
        current: String,
        goal: String,
        progress: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 7) {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.16))
                            .frame(width: 28, height: 28)
                        Image(systemName: icon)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(color)
                    }
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                Spacer()
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(current)
                        .font(.system(size: 17, weight: .black, design: .rounded).monospacedDigit())
                        .foregroundStyle(color)
                    Text("/ \(goal)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            GradientProgressBar(value: progress, color: progress >= 1.0 ? .green : color, height: 10)

            if progress >= 1.0 {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption.bold())
                    Text("Goal achieved!")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.green)
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color.green.opacity(0.12), in: Capsule())
                .overlay(Capsule().stroke(Color.green.opacity(0.20), lineWidth: 0.5))
            }
        }
    }
}
