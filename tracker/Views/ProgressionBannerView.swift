import SwiftUI

struct ProgressionBannerView: View {
    let recommendation: ProgressionRecommendation
    @Environment(\.weightUnit) private var weightUnit

    private var icon: String {
        switch recommendation.action {
        case .increase: return "arrow.up.circle.fill"
        case .hold: return "equal.circle.fill"
        case .deload: return "arrow.down.circle.fill"
        case .insufficient: return "questionmark.circle"
        }
    }

    private var color: Color {
        switch recommendation.action {
        case .increase: return .green
        case .hold: return .blue
        case .deload: return .orange
        case .insufficient: return .secondary
        }
    }

    private var formattedDetail: String {
        switch recommendation.action {
        case .increase(let suggestedKg):
            let formatted = weightUnit.format(suggestedKg)
            return "Try \(formatted) next session. \(recommendation.detail)"
        default:
            return recommendation.detail
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(recommendation.headline)
                    .font(.subheadline.weight(.semibold))
                Text(formattedDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
