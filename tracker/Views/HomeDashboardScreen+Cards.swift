import SwiftUI

extension HomeDashboardScreen {

    @ViewBuilder
    var momentumCard: some View {
        let milestones = [3, 7, 14, 30, 50, 75, 100, 150, 200, 365]
        if snapshot.currentStreak >= 2, let next = milestones.first(where: { $0 > snapshot.currentStreak }) {
            NavigationLink { StreakCalendarView() } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous)
                            .fill(LinearGradient(colors: [.orange, AppTheme.Signal.runOrange], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 48, height: 48)
                            .shadow(color: .orange.opacity(0.4), radius: 8, y: 4)
                        Image(systemName: "flame.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(snapshot.currentStreak)-Day Streak")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        GradientProgressBar(value: Double(snapshot.currentStreak) / Double(next), color: .orange, height: 6)
                        Text("\(next - snapshot.currentStreak) more to your \(next)-day milestone.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(16)
                .background(
                    LinearGradient(
                        colors: [Color.orange.opacity(0.10), Color(.secondarySystemGroupedBackground)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                )
            }
            .buttonStyle(.pressableCard)
        }
    }
}
