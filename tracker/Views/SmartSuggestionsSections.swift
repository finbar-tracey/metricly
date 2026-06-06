import SwiftUI

enum SmartSuggestionsSections {

    static func heroCard(
        suggestedWorkoutType: String,
        muscleReadiness: [(MuscleGroup, Double)]
    ) -> some View {
        HeroCard(palette: [
            AppTheme.Signal.focus,
            Color(red: 0.40, green: 0.40, blue: 0.92),
            AppTheme.Signal.calm
        ]) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial.opacity(0.7))
                            .frame(width: 56, height: 56)
                            .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.5))
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Suggested")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))
                            .tracking(0.5)
                            .textCase(.uppercase)
                        Text(suggestedWorkoutType)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                }

                FlowLayout(spacing: 6) {
                    ForEach(muscleReadiness, id: \.0) { group, freshness in
                        HStack(spacing: 5) {
                            Circle()
                                .fill(RecoveryEngine.freshnessColor(freshness))
                                .frame(width: 8, height: 8)
                                .shadow(color: RecoveryEngine.freshnessColor(freshness).opacity(0.6), radius: 3)
                            Text(group.rawValue)
                                .font(.caption2.weight(.semibold))
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial.opacity(0.6), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.20), lineWidth: 0.5))
                        .foregroundStyle(.white)
                    }
                }

                Text("Based on your recovery and training history")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.78))
            }
            .padding(20)
        }
    }

    static func suggestionsCard(
        suggestions: [SuggestedExercise],
        onCreateWorkout: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Suggested Exercises", icon: "sparkles", color: .accentColor)

            VStack(spacing: 0) {
                ForEach(Array(suggestions.enumerated()), id: \.element.id) { idx, suggestion in
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: AppTheme.chipRadius)
                                .fill(Color.accentColor.opacity(0.12))
                                .frame(width: 38, height: 38)
                            MuscleIconView(group: suggestion.group, color: Color.accentColor)
                                .frame(width: 16, height: 16)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(suggestion.name)
                                .font(.subheadline.weight(.semibold))
                            HStack(spacing: 6) {
                                Text(suggestion.group.rawValue)
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 7).padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.12), in: Capsule())
                                    .foregroundStyle(Color.accentColor)
                                Text(suggestion.reason)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    if idx < suggestions.count - 1 {
                        Divider().padding(.leading, 68)
                    }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.tileRadius))

            Button(action: onCreateWorkout) {
                Label("Create Workout from Suggestions", systemImage: "plus.circle.fill")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor.gradient)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
            }
            .buttonStyle(.plain)
        }
        .appCard()
    }

    static func howItWorksCard() -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "How It Works", icon: "info.circle.fill", color: .secondary)

            VStack(spacing: 0) {
                infoRow(icon: "heart.text.square", color: .red, text: "Muscles with 70%+ recovery are prioritized")
                Divider().padding(.leading, 50)
                infoRow(icon: "clock.arrow.circlepath", color: .orange, text: "Exercises not done in the last 7 days are preferred")
                Divider().padding(.leading, 50)
                infoRow(icon: "chart.bar", color: .blue, text: "Suggestions update as you train more")
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.tileRadius))
        }
        .appCard()
    }

    private static func infoRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.12)).frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(text).font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
    }
}
