import SwiftUI

/// Compact "top insight" card shown on Home, surfacing the highest-weighted
/// pattern from the most recent `PersonalInsightsEngine` run. Tap to switch
/// to the Insights tab. Own struct to keep `HomeDashboardView`'s opaque-type
/// chain manageable.
struct TopInsightCardView: View {
    let insight: Insight
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(categoryColor)
                Text("Pattern spotted")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(categoryColor)
                    .textCase(.uppercase)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(categoryColor.opacity(0.14))
                        .frame(width: 38, height: 38)
                    Image(systemName: insight.icon)
                        .font(.system(size: 16, weight: .semibold))
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
        .appCard()
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
