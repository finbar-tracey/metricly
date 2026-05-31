import SwiftUI

/// Tier cards, achievement rows, and "Almost There" nudge for Achievements.
enum AchievementsGridSection {

    // MARK: - Almost There

    @ViewBuilder
    static func almostThereCard(
        allAchievements: [Achievement],
        selectedCategory: Binding<Achievement.Category?>
    ) -> some View {
        let nextUp = Array(
            allAchievements
                .filter { !$0.isUnlocked && ($0.progress ?? 0) > 0.01 }
                .sorted { ($0.progress ?? 0) > ($1.progress ?? 0) }
                .prefix(3)
        )
        if !nextUp.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Almost There", icon: "target", color: .orange)
                VStack(spacing: 0) {
                    ForEach(Array(nextUp.enumerated()), id: \.element.id) { idx, a in
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                selectedCategory.wrappedValue = a.category
                            }
                        } label: {
                            nextUpRow(a)
                        }
                        .buttonStyle(.plain)
                        if idx < nextUp.count - 1 {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous))
            }
            .appCard()
        }
    }

    // MARK: - Tier Cards

    @ViewBuilder
    static func achievementTiersCards(filteredAchievements: [Achievement]) -> some View {
        ForEach(Achievement.Tier.allCases, id: \.self) { tier in
            let tierItems = filteredAchievements.filter { $0.tier == tier }
            if !tierItems.isEmpty {
                tierCard(tier: tier, items: tierItems)
            }
        }
    }

    // MARK: - Private

    private static func tierCard(tier: Achievement.Tier, items: [Achievement]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(tier.color.opacity(0.15)).frame(width: 28, height: 28)
                    Image(systemName: "medal.fill")
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(tier.color)
                }
                Text(tier.rawValue.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                let unlockedCount = items.filter(\.isUnlocked).count
                Text("\(unlockedCount)/\(items.count)")
                    .font(.caption2.bold().monospacedDigit()).foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, achievement in
                    achievementRow(achievement)
                    if idx < items.count - 1 { Divider().padding(.leading, 62) }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    private static func achievementRow(_ achievement: Achievement) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? achievement.tier.color.opacity(0.20) : Color(.systemFill))
                    .frame(width: 44, height: 44)
                Image(systemName: achievement.icon)
                    .font(.title3)
                    .foregroundStyle(achievement.isUnlocked ? achievement.tier.color : Color.secondary.opacity(0.4))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(achievement.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(achievement.isUnlocked ? .primary : .secondary)
                    Image(systemName: achievement.category.icon)
                        .font(.caption2).foregroundStyle(achievement.category.color)
                }
                Text(achievement.description)
                    .font(.caption).foregroundStyle(.secondary)
                if let date = achievement.unlockedDate, achievement.isUnlocked {
                    Text(date, format: .dateTime.month(.abbreviated).day().year())
                        .font(.caption2).foregroundStyle(.tertiary)
                } else if let progress = achievement.progress, !achievement.isUnlocked {
                    HStack(spacing: 6) {
                        GradientProgressBar(value: progress, color: achievement.category.color, height: 4)
                            .frame(maxWidth: 120)
                        Text("\(Int(progress * 100))%")
                            .font(.caption2.bold().monospacedDigit())
                            .foregroundStyle(achievement.category.color)
                    }
                }
            }

            Spacer()

            if achievement.isUnlocked {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Image(systemName: "lock.fill").foregroundStyle(.tertiary)
            }
        }
        .opacity(achievement.isUnlocked ? 1.0 : 0.65)
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private static func nextUpRow(_ a: Achievement) -> some View {
        let progress = a.progress ?? 0
        return HStack(spacing: 14) {
            ZStack {
                Circle().fill(a.category.color.opacity(0.16)).frame(width: 44, height: 44)
                Image(systemName: a.icon)
                    .font(.title3)
                    .foregroundStyle(a.category.color)
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(a.name)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(a.category.color)
                }
                GradientProgressBar(value: progress, color: a.category.color, height: 6)
                Text(a.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}
