import SwiftUI

enum StreakCalendarHeroSections {

    // MARK: - Next Milestone

    @ViewBuilder
    static func nextMilestoneCard(
        currentStreak: Int,
        longestStreak: Int
    ) -> some View {
        let milestones = [7, 14, 30, 50, 75, 100, 150, 200, 365]
        if currentStreak >= 1, let next = milestones.first(where: { $0 > currentStreak }) {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Next Milestone", icon: "flag.checkered", color: .orange)
                HStack(alignment: .firstTextBaseline) {
                    Text("\(next)-Day Streak")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Spacer()
                    Text("\(next - currentStreak) to go")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                        .monospacedDigit()
                }
                GradientProgressBar(value: Double(currentStreak) / Double(next), color: .orange, height: 8)
                if longestStreak > currentStreak {
                    Text("\(longestStreak - currentStreak) more to beat your best of \(longestStreak).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if currentStreak == longestStreak {
                    Text("You're at your all-time best — keep it going!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .appCard()
        }
    }

    // MARK: - Hero

    static func heroCard(
        currentStreak: Int,
        longestStreak: Int,
        thisWeekCount: Int,
        thisMonthCount: Int,
        totalWorkouts: Int
    ) -> some View {
        HeroCard(palette: AppTheme.Gradients.caution) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial.opacity(0.7))
                            .frame(width: 56, height: 56)
                            .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.5))
                        Image(systemName: "flame.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Current Streak")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))
                            .tracking(0.5)
                            .textCase(.uppercase)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            AnimatedInt(
                                value: currentStreak,
                                font: .system(size: 44, weight: .black, design: .rounded),
                                color: .white
                            )
                            .shadow(color: .black.opacity(0.18), radius: 5, y: 3)
                            Text(currentStreak == 1 ? "day" : "days")
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white.opacity(0.78))
                        }
                    }
                    Spacer()
                    if longestStreak > 0 {
                        VStack(spacing: 4) {
                            Image(systemName: "trophy.fill")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.95))
                            Text("\(longestStreak)")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .monospacedDigit()
                            Text("BEST")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.78))
                                .tracking(0.5)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(.ultraThinMaterial.opacity(0.7), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(.white.opacity(0.25), lineWidth: 0.5)
                        )
                    }
                }

                HStack(spacing: 0) {
                    HeroStatCol(value: "\(thisWeekCount)", label: "This Week")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 32)
                    HeroStatCol(value: "\(thisMonthCount)", label: "This Month")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 32)
                    HeroStatCol(value: "\(totalWorkouts)", label: "Total")
                }
                .padding(.vertical, 10)
                .background(.ultraThinMaterial.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 0.5)
                )
            }
            .padding(20)
        }
    }

    // MARK: - Rest Day

    static func restDayCard(currentStreak: Int, onDismiss: @escaping () -> Void) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.indigo, Color(red: 0.40, green: 0.30, blue: 0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                    .shadow(color: .indigo.opacity(0.40), radius: 6, y: 3)
                Image(systemName: "bed.double.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Consider a rest day")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text("\(currentStreak)-day streak — recovery helps muscles grow.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                    onDismiss()
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .buttonStyle(.pressableCard)
            .accessibilityLabel("Dismiss")
        }
        .appCard()
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}
