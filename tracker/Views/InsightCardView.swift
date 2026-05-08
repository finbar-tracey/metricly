import SwiftUI

/// Single insight card showing one personal pattern. Own struct to keep the
/// `InsightsView` body's opaque-type chain manageable.
struct InsightCardView: View {
    let insight: Insight

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(categoryColor.opacity(0.16))
                        .frame(width: 36, height: 36)
                    Image(systemName: insight.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(categoryColor)
                }
                Text(insight.title)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(2)
                Spacer()
                strengthBadge
            }

            Text(insight.message)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if let detail = insight.detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .appCard()
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

    private var strengthBadge: some View {
        let color: Color = {
            switch insight.strength {
            case .weak:     return .secondary
            case .moderate: return .blue
            case .strong:   return .green
            }
        }()
        return Text(insight.strength.label)
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.14), in: Capsule())
    }
}
