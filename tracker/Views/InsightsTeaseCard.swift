import SwiftUI

/// Surfaces the Insights tab on Home when there are no cached
/// insights yet but the user has logged enough sessions to be eligible.
/// Without this, the most magical part of the app (pattern detection
/// across sleep / recovery / training) stays invisible until the user
/// discovers the Insights tab on their own — which the v1.5 review
/// flagged as a real onboarding gap.
///
/// Visually similar to `TopInsightCardView` so the surface feels
/// consistent when an insight does arrive: same chevron, same compact
/// chrome, same `Sparkles` accent. The copy is the only difference —
/// "Pattern spotted" / "Find your first pattern" — so users who tap
/// understand what they're stepping into.
struct InsightsTeaseCard: View {
    let onTap: () -> Void

    private let accent: Color = .indigo

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .bold))
                    Text("Patterns")
                        .font(.caption2.weight(.bold))
                        .textCase(.uppercase)
                        .tracking(0.4)
                }
                .foregroundStyle(accent)
                .padding(.horizontal, 9).padding(.vertical, 4)
                .gradientCapsule(accent)
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
                                colors: [accent.opacity(0.28), accent.opacity(0.12)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                        .overlay(Circle().stroke(accent.opacity(0.30), lineWidth: 0.5))
                        .shadow(color: accent.opacity(0.25), radius: 5, y: 3)
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(accent)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Find your first training pattern")
                        .font(.subheadline.weight(.bold))
                    Text("Metricly can look for links between your sleep, recovery and lifting performance. Tap to run the engine.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
        }
        .tintedCallout(accent)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Find your first training pattern. Tap to open Insights.")
    }
}

#Preview {
    InsightsTeaseCard {}
        .padding()
        .background(Color(.systemGroupedBackground))
}
