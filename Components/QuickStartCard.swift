import SwiftUI

struct QuickStartCard: View {
    let programName: String
    let workoutName: String
    let onStart: () -> Void

    var body: some View {
        HeroCard(palette: AppTheme.Gradients.calm) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial.opacity(0.7))
                            .frame(width: 44, height: 44)
                            .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.5))
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today's Workout")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))
                            .tracking(0.5)
                            .textCase(.uppercase)
                        Text(workoutName)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    Text(programName)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial.opacity(0.7), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 0.5))
                        .foregroundStyle(.white)
                }

                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onStart()
                }) {
                    HStack(spacing: 7) {
                        Image(systemName: "play.fill")
                        Text("Start Workout")
                    }
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(.white)
                    .foregroundStyle(AppTheme.Signal.calm)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                }
                .buttonStyle(.pressableCard)
            }
            .padding(20)
        }
    }
}
