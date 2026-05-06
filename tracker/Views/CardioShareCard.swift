import SwiftUI

// MARK: - Shareable card view (rendered to image by ImageRenderer)

struct CardioShareCard: View {
    let session: CardioSession
    let useKm: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background gradient
            LinearGradient(
                colors: [
                    session.type.color,
                    session.type.color.opacity(0.78),
                    session.type.color.opacity(0.55)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            // Top sheen
            LinearGradient(
                colors: [.white.opacity(0.18), .clear],
                startPoint: .top, endPoint: .center
            )
            .blendMode(.plusLighter)

            // Decorative circles (blurred for depth)
            Circle()
                .fill(.white.opacity(0.10))
                .frame(width: 220)
                .blur(radius: 14)
                .offset(x: 240, y: -80)
            Circle()
                .fill(.white.opacity(0.06))
                .frame(width: 140)
                .blur(radius: 10)
                .offset(x: 280, y: 100)

            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial.opacity(0.7))
                            .frame(width: 52, height: 52)
                            .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.5))
                        Image(systemName: session.type.icon)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.type.rawValue)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))
                            .tracking(0.5)
                            .textCase(.uppercase)
                        Text(session.date, format: .dateTime.weekday(.wide).month(.abbreviated).day().year())
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    // App badge
                    Text("METRICLY")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(0.6)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(.ultraThinMaterial.opacity(0.7), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 0.5))
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
