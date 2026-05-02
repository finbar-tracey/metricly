import SwiftUI

// MARK: - Shareable card view (rendered to image by ImageRenderer)

struct CardioShareCard: View {
    let session: CardioSession
    let useKm: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background gradient
            LinearGradient(
                colors: [session.type.color, session.type.color.opacity(0.6)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            // Decorative circles
            Circle()
                .fill(.white.opacity(0.06))
                .frame(width: 220)
                .offset(x: 240, y: -80)
            Circle()
                .fill(.white.opacity(0.04))
                .frame(width: 140)
                .offset(x: 280, y: 100)

            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(.white.opacity(0.2)).frame(width: 48, height: 48)
                        Image(systemName: session.type.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.type.rawValue)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.75))
                        Text(session.date, format: .dateTime.weekday(.wide).month(.abbreviated).day().year())
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    // App badge
                    Text("Metricly")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.white.opacity(0.15), in: Capsule())
                }

                // Main stat — distance
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.formattedDistance(useKm: useKm))
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text("Distance").font(.caption.weight(.medium)).foregroundStyle(.white.opacity(0.7))
                }

                // Secondary stats strip
                HStack(spacing: 0) {
                    shareStatCol(label: "Duration",  value: session.formattedDuration)
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 32)
                    shareStatCol(label: "Avg Pace",  value: session.formattedPace(useKm: useKm))
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 32)
                    let cal = session.caloriesBurned ?? session.estimatedCalories()
                    shareStatCol(label: "Calories",  value: String(format: "%.0f kcal", cal))
                    if session.elevationGainMeters > 1 {
                        Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 32)
                        shareStatCol(label: "Elevation", value: String(format: "%.0f m", session.elevationGainMeters))
                    }
                }
                .padding(.vertical, 12)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(22)
        }
        .frame(width: 380, height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func shareStatCol(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Share helper

@MainActor
func renderCardioShareImage(session: CardioSession, useKm: Bool) -> UIImage? {
    let card = CardioShareCard(session: session, useKm: useKm)
    let renderer = ImageRenderer(content: card)
    renderer.scale = 3   // 3× for crisp sharing
    return renderer.uiImage
}
