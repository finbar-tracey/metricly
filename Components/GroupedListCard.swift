import SwiftUI

/// Card that wraps a list of rows under a `SectionHeader`, with the
/// tertiary-system-grouped-background ring + 14pt rounded clip + the
/// shared `.appCard()` chrome. Four sites in `MuscleRecoveryView`
/// (Health Factors, External Activity, Reported Soreness, By Muscle
/// Group) each rebuilt this shell independently before consolidation —
/// the Sprint-17 v1.5 review flagged it as the highest-duplication
/// pattern in the view layer.
///
/// Optional `footnote` renders a `caption2 / tertiary` line below the
/// row container (used for "Counts for 48 hours" / "Updated just now"
/// kind of disclosures).
struct GroupedListCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    var footnote: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: title, icon: icon, color: color)
            VStack(spacing: 0) {
                content()
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous))

            if let footnote {
                Text(footnote)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            }
        }
        .appCard()
    }
}
