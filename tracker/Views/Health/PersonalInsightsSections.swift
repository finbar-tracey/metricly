import SwiftUI

enum PersonalInsightsSections {

    static func complianceCard(_ summary: TodayPlanEngine.ComplianceSummary) -> some View {
        let pct = Int((summary.rate * 100).rounded())
        let followed = Int((Double(summary.sampleSize) * summary.rate).rounded())
        let tint: Color = summary.rate >= 0.7
            ? AppTheme.Signal.recovery
            : (summary.rate >= 0.5 ? AppTheme.Signal.caution : AppTheme.Signal.strain)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.28), tint.opacity(0.12)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .overlay(Circle().stroke(tint.opacity(0.30), lineWidth: 0.5))
                        .shadow(color: tint.opacity(0.25), radius: 5, y: 3)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(.title3))
                        .foregroundStyle(tint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Plan compliance", comment: "Card title for the plan-compliance summary on the Patterns tab"))
                        .font(.subheadline.weight(.semibold))
                    Text(String(localized: "Followed \(followed) of \(summary.sampleSize) plans in the last week", comment: "Subtitle showing how many recommended plans the user actually followed"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(pct)%")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(tint)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.15))
                    Capsule().fill(tint)
                        .frame(width: geo.size.width * max(0.02, summary.rate))
                }
            }
            .frame(height: 6)

            if let kind = summary.mostIgnoredKind, summary.ignoredCount(for: kind) > 0 {
                Text(mostIgnoredLine(for: kind, count: summary.ignoredCount(for: kind)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .appCard()
        .accessibilityElement(children: .combine)
    }

    static func headerCard() -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.indigo.opacity(0.28), Color.indigo.opacity(0.12)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(Circle().stroke(Color.indigo.opacity(0.30), lineWidth: 0.5))
                    .shadow(color: Color.indigo.opacity(0.25), radius: 5, y: 3)
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.indigo)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(String(
                    localized: "Personal patterns",
                    comment: "Title of the Insights tab header card"
                ))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text(String(
                    localized: "Trends spotted in your training, sleep and recovery data over the last 90 days. These are observations, not medical advice.",
                    comment: "Subtitle disclaimer under the Insights tab header card"
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
        .accessibilityElement(children: .combine)
    }

    static func footerCard() -> some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(String(
                localized: "Patterns improve as you log more data. Most insights need 90+ days and 8+ matching sessions before they appear.",
                comment: "Footer explaining the data threshold for insights"
            ))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .accessibilityElement(children: .combine)
    }

    static func emptyState() -> some View {
        EmptyStateView(
            icon: "sparkles",
            title: String(
                localized: "Not enough data yet",
                comment: "Empty-state title shown when the insights engine produced zero results"
            ),
            subtitle: String(
                localized: "Keep logging workouts and connecting Health data — we'll surface patterns as soon as we have enough to compare.",
                comment: "Empty-state subtitle explaining how more data unlocks insights"
            )
        )
        .appCard()
    }

    static func loadingState() -> some View {
        LoadingStateView(String(
            localized: "Looking for patterns…",
            comment: "Status text while the insights engine is computing"
        ))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(
            localized: "Looking for patterns",
            comment: "VoiceOver label for the patterns loading state"
        ))
    }

    // MARK: - Private

    private static func mostIgnoredLine(for kind: TodayPlan.Intensity, count: Int) -> String {
        switch kind {
        case .rest:
            return String(localized: "Most often skipped: rest days (\(count))", comment: "Footnote naming the most-ignored intensity bucket")
        case .light:
            return String(localized: "Most often skipped: light days (\(count))", comment: "Footnote naming the most-ignored intensity bucket")
        case .moderate:
            return String(localized: "Most often skipped: moderate days (\(count))", comment: "Footnote naming the most-ignored intensity bucket")
        case .hard:
            return String(localized: "Most often skipped: hard days (\(count))", comment: "Footnote naming the most-ignored intensity bucket")
        }
    }
}
