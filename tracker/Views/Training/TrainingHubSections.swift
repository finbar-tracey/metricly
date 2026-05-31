import SwiftUI

enum TrainingHubSections {

    static func trainingHeroCard(
        finishedWorkoutCount: Int,
        currentStreak: Int,
        uniqueExerciseCount: Int,
        weeklyCardioKm: Double,
        weightUnit: WeightUnit,
        onStartWorkout: @escaping () -> Void
    ) -> some View {
        HeroCard(palette: AppTheme.Gradients.calm) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 6) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("Training")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .tracking(0.5)
                        .textCase(.uppercase)
                }

                HStack(spacing: 0) {
                    HeroStatCol(value: "\(finishedWorkoutCount)", label: "Workouts",
                                icon: "figure.strengthtraining.traditional")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 40)
                    HeroStatCol(value: "\(currentStreak)", label: "Streak", icon: "flame.fill")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 40)
                    HeroStatCol(value: "\(uniqueExerciseCount)", label: "Exercises", icon: "dumbbell.fill")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 40)
                    HeroStatCol(
                        value: weeklyCardioKm > 0.05 ? weightUnit.distanceUnit.format(weeklyCardioKm) : "—",
                        label: "\(weightUnit.distanceUnit.label) this wk",
                        icon: "figure.run"
                    )
                }
                .padding(.vertical, 12)
                .background(.ultraThinMaterial.opacity(0.55), in: RoundedRectangle(cornerRadius: AppTheme.miniCardRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.miniCardRadius, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 0.5)
                )

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onStartWorkout()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("Start Workout")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(AppTheme.Signal.calm)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                }
                .buttonStyle(.pressableCard)
                .accessibilityLabel("Start Workout")
                .accessibilityHint("Opens the add workout sheet")
            }
            .padding(20)
        }
        .frame(minHeight: 145)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Training summary")
    }

    static func cardioHeroRow(
        lastSession: CardioSession?,
        weeklyCardioKm: Double,
        weightUnit: WeightUnit
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.orange, AppTheme.Signal.actionOrange],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 46, height: 46)
                    .shadow(color: .orange.opacity(0.42), radius: 8, x: 0, y: 4)
                Image(systemName: "figure.run")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Run & Cardio")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                if let last = lastSession {
                    Text(lastSessionSummary(last))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("GPS tracking, splits, pace & route")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if weeklyCardioKm > 0.05 {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(weightUnit.distanceUnit.format(weeklyCardioKm))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                        .monospacedDigit()
                    Text("this week")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    static func resumeRow(_ workout: Workout) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.orange, AppTheme.Signal.actionOrange],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 46, height: 46)
                    .shadow(color: .orange.opacity(0.42), radius: 8, x: 0, y: 4)
                Image(systemName: "play.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Resume Workout")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(workout.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text("IN PROGRESS")
                .font(.system(size: 9, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(.orange)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.orange.opacity(0.14), in: Capsule())
                .overlay(Capsule().stroke(Color.orange.opacity(0.25), lineWidth: 0.5))
        }
        .padding(.vertical, 5)
    }

    private static func lastSessionSummary(_ s: CardioSession) -> String {
        let dist = s.distanceMeters > 0
            ? String(format: "%.2f km", s.distanceMeters / 1000)
            : s.formattedDuration
        let ago = s.date.formatted(.relative(presentation: .named, unitsStyle: .abbreviated))
        return "\(s.type.shortName) · \(dist) · \(ago)"
    }
}
