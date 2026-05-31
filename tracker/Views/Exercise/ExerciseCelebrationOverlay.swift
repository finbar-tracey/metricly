import SwiftUI

/// PR and goal celebration banners for [`ExerciseDetailView`].
struct ExerciseCelebrationOverlay: View {
    @Bindable var session: ExerciseSessionState
    let exerciseName: String
    let weightUnit: WeightUnit

    var body: some View {
        VStack(spacing: 0) {
            if session.showPRBanner {
                celebrationCard(
                    icon: "trophy.fill",
                    title: "NEW PERSONAL RECORD",
                    subtitle: exerciseName,
                    value: weightUnit.format(session.prWeight),
                    gradient: AppTheme.Gradients.caution,
                    accent: AppTheme.Signal.amber,
                    scale: session.prScale,
                    accessibilityLabel: "New personal record! \(exerciseName), \(weightUnit.format(session.prWeight))"
                )
            }
            if session.showGoalBanner {
                celebrationCard(
                    icon: "target",
                    title: "GOAL ACHIEVED",
                    subtitle: exerciseName,
                    value: "\(weightUnit.format(session.goalTarget)) reached!",
                    gradient: AppTheme.Gradients.recovery,
                    accent: AppTheme.Signal.recovery,
                    scale: session.goalScale,
                    accessibilityLabel: "Goal achieved! \(exerciseName), \(weightUnit.format(session.goalTarget))"
                )
            }
        }
    }

    private func celebrationCard(
        icon: String,
        title: String,
        subtitle: String,
        value: String,
        gradient: [Color],
        accent: Color,
        scale: CGFloat,
        accessibilityLabel: String
    ) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [accent, accent.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 52, height: 52)
                    .shadow(color: accent.opacity(0.55), radius: 12, y: 4)
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text(title)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.9))
            Text(subtitle)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
            Text(value)
                .font(.system(size: title.contains("GOAL") ? 22 : 30, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 18)
        .background(
            LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: AppTheme.heroRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.heroRadius, style: .continuous)
                .stroke(.white.opacity(0.25), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.28), radius: 24, y: 10)
        .scaleEffect(scale)
        .padding(.top, 12)
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .scale(scale: 0.5)).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        ))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }
}
