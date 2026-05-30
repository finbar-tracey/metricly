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
        .padding(16)
        .background(
            ZStack {
                Color(.secondarySystemGroupedBackground)
                LinearGradient(
                    colors: [categoryColor.opacity(0.10), .clear],
                    startPoint: .topLeading, endPoint: .center
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .stroke(categoryColor.opacity(0.20), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: 5)
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
            .padding(.horizontal, 9).padding(.vertical, 3)
            .background(
                LinearGradient(
                    colors: [color.opacity(0.20), color.opacity(0.10)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                in: Capsule()
            )
            .overlay(Capsule().stroke(color.opacity(0.22), lineWidth: 0.5))
    }
}
