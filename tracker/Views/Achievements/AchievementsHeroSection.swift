import SwiftUI

/// Hero card, category filter, and unlock celebration overlay for Achievements.
enum AchievementsHeroSection {

    // MARK: - Hero

    static func heroCard(allAchievements: [Achievement]) -> some View {
        let unlocked = allAchievements.filter(\.isUnlocked).count
        let total = allAchievements.count

        return HeroCard(palette: [
            AppTheme.Signal.amber,
            Color(red: 0.85, green: 0.42, blue: 0.10),
            Color(red: 0.65, green: 0.28, blue: 0.30)
        ]) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial.opacity(0.7))
                            .frame(width: 56, height: 56)
                            .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.5))
                        Image(systemName: "medal.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Achievements")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))
                            .tracking(0.5)
                            .textCase(.uppercase)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            AnimatedInt(
                                value: unlocked,
                                font: .system(size: 42, weight: .black, design: .rounded),
                                color: .white
                            )
                            .shadow(color: .black.opacity(0.18), radius: 5, y: 3)
                            Text("/ \(total)")
                                .font(.system(size: 20, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white.opacity(0.78))
                        }
                    }
                    Spacer()
                    Text("\(Int(Double(unlocked) / Double(max(1, total)) * 100))%")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .padding(.horizontal, 11).padding(.vertical, 5)
                        .background(.ultraThinMaterial.opacity(0.70), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 0.5))
                        .foregroundStyle(.white)
                }

                GradientProgressBar(value: Double(unlocked) / Double(max(1, total)), color: .white, height: 8)

                HStack(spacing: 0) {
                    ForEach(Achievement.Category.allCases, id: \.self) { cat in
                        let catAll = allAchievements.filter { $0.category == cat }
                        let catUnlocked = catAll.filter(\.isUnlocked).count
                        VStack(spacing: 5) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white.opacity(0.92))
                            Text("\(catUnlocked)/\(catAll.count)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.78))
                                .monospacedDigit()
                        }
                        .frame(maxWidth: .infinity)
                    }
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

    // MARK: - Category Picker

    static func categoryPickerCard(selectedCategory: Binding<Achievement.Category?>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Category", icon: "tag.fill", color: .accentColor)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(label: "All", icon: "medal.fill", color: .yellow, isSelected: selectedCategory.wrappedValue == nil) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedCategory.wrappedValue = nil }
                    }
                    ForEach(Achievement.Category.allCases, id: \.self) { cat in
                        filterChip(label: cat.rawValue, icon: cat.icon, color: cat.color, isSelected: selectedCategory.wrappedValue == cat) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedCategory.wrappedValue = cat }
                        }
                    }
                }
            }
        }
        .appCard()
    }

    // MARK: - Celebration Overlay

    @ViewBuilder
    static func celebrationOverlay(celebrating: Achievement?, onTap: @escaping () -> Void) -> some View {
        if let a = celebrating {
            ZStack {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onTap)
                VStack(spacing: 8) {
                    ZStack {
                        Circle().fill(.white.opacity(0.20)).frame(width: 58, height: 58)
                        Image(systemName: a.icon)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    Text("ACHIEVEMENT UNLOCKED")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.9))
                    Text(a.name)
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text("\(a.tier.rawValue) · \(a.category.rawValue)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.78))
                    Text(a.description)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.82))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding(.horizontal, 28).padding(.vertical, 22)
                .frame(maxWidth: 300)
                .background(
                    LinearGradient(
                        colors: [a.category.color, a.category.color.opacity(0.72)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: AppTheme.heroRadius, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.heroRadius, style: .continuous)
                        .stroke(.white.opacity(0.25), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.30), radius: 24, y: 10)
                .onTapGesture(perform: onTap)
                .transition(.scale(scale: 0.7).combined(with: .opacity))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Achievement unlocked: \(a.name), \(a.description)")
            }
        }
    }

    // MARK: - Private

    private static func filterChip(label: String, icon: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        FilterChip(label: label, icon: icon, color: color, isSelected: isSelected, action: action)
    }
}
