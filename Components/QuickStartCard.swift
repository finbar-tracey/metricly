import SwiftUI

struct QuickStartCard: View {
    let programName: String
    let workoutName: String
    let onStart: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Color.accentColor, Color.accentColor.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(.white.opacity(0.06))
                .frame(width: 160)
                .offset(x: 180, y: -50)

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.20))
                            .frame(width: 40, height: 40)
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today's Workout")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.75))
                        Text(workoutName)
                            .font(.headline)
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    Text(programName)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.20))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }

                Button(action: onStart) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                        Text("Start Workout")
                    }
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.white)
                    .foregroundStyle(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
            .padding(18)
        }
        .heroCard()
    }
}
