import SwiftUI

/// Compact "top insight" card shown on Home, surfacing the highest-weighted
/// pattern from the most recent `PersonalInsightsEngine` run. Tap to switch
/// to the Insights tab. Own struct to keep `HomeDashboardView`'s opaque-type
/// chain manageable.
struct TopInsightCardView: View {
    let insight: Insight
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .bold))
                    Text("Pattern spotted")
                        .font(.caption2.weight(.bold))
                        .textCase(.uppercase)
                        .tracking(0.4)
                }
                .foregroundStyle(categoryColor)
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(
                    LinearGradient(
                        colors: [categoryColor.opacity(0.20), categoryColor.opacity(0.10)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    in: Capsule()
                )
                .overlay(Capsule().stroke(categoryColor.opacity(0.25), lineWidth: 0.5))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [categoryColor.opacity(0.28), categoryColor.opacity(0.12)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                        .overlay(Circle().stroke(categoryColor.opacity(0.30), lineWidth: 0.5))
                        .shadow(color: categoryColor.opacity(0.25), radius: 5, y: 3)
                    Image(systemName: insight.icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(categoryColor)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.title)
                        .font(.subheadline.weight(.bold))
                        .lineLimit(2)
                    Text(insight.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
        }
        .tintedCallout(categoryColor)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private var categoryColor: Color {
        switch insight.category {
        case .sleep:       return .indigo
        case .recovery:    return .teal
        case .performance: return .orange
        case .caffeine:    return .brown
        case .cardio:      return .red
        case .consistency: return .green
        }
    }
}
