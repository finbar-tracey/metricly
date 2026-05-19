import SwiftUI

/// Single-line CTA banner that adapts to current state: ready to train,
/// workout in progress, rest day, or "nice work today" after a session.
/// The parent decides which case to show and supplies the action.
struct HomeContextualCTASection: View {
    enum Kind {
        case continueWorkout(Workout)
        case greatSession(totalSets: Int, totalVolumeKg: Double)
    }

    let kind: Kind
    let weightUnit: WeightUnit

    var body: some View {
        switch kind {
        case .continueWorkout(let workout):
            NavigationLink(value: workout) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(Color.orange.opacity(0.16)).frame(width: 50, height: 50)
                        Image(systemName: "play.fill")
                            .font(.system(size: 20, weight: .semibold)).foregroundStyle(.orange)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Workout in progress")
                            .font(.subheadline.weight(.semibold))
                        Text(workout.name).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("Continue")
                        .font(.subheadline.bold()).foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(
                            LinearGradient(
                                colors: [.orange, AppTheme.Signal.actionOrange],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            in: Capsule()
                        )
                        .shadow(color: .orange.opacity(0.45), radius: 8, x: 0, y: 4)
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                }
                .appCard()
            }
            .buttonStyle(.pressableCard)

        case .greatSession(let sets, let volumeKg):
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.yellow.opacity(0.12)).frame(width: 50, height: 50)
                    Image(systemName: "star.fill")
                        .font(.system(size: 20, weight: .semibold)).foregroundStyle(.yellow)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Nice work today!")
                        .font(.subheadline.weight(.semibold))
                    Text("\(sets) set\(sets == 1 ? "" : "s") logged · \(weightUnit.formatShort(volumeKg)) volume")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .appCard()
        }
    }
}
