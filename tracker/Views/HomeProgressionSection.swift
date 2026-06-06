import SwiftUI

/// "Ready to Progress" list on the home dashboard — the top suggestions
/// from ProgressionAdvisor. Each row deep-links to ExerciseHistoryView
/// via NavigationLink(value: String) which the parent registers.
struct HomeProgressionSection: View {
    /// (exerciseName, recommendation). Use a value-typed wrapper so the
    /// view doesn't need to know how the parent assembled it.
    struct Suggestion: Identifiable {
        let id: UUID
        let exerciseName: String
        let recommendation: ProgressionRecommendation
    }

    let suggestions: [Suggestion]
    let weightUnit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Ready to Progress", icon: "chart.line.uptrend.xyaxis", color: .green)

            VStack(spacing: 0) {
                ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                    NavigationLink(value: suggestion.exerciseName) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [.green, AppTheme.Signal.actionGreen],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 38, height: 38)
                                    .shadow(color: .green.opacity(0.40), radius: 6, y: 3)
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(suggestion.exerciseName)
                                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                if case .increase(let kg) = suggestion.recommendation.action {
                                    Text("Try \(weightUnit.format(kg)) next session")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                    }
                    .buttonStyle(.pressableCard)
                    if index < suggestions.count - 1 { Divider().padding(.leading, 66) }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous)
                    .stroke(AppTheme.cardHairline, lineWidth: 0.5)
            )
        }
        .appCard()
    }
}
