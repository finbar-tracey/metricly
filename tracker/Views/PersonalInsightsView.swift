import SwiftUI
import SwiftData

/// "Patterns" view inside the Insights tab — shows correlation-based insights
/// from `PersonalInsightsEngine`. Pulls 90 days of HealthKit history on first
/// appear, runs the engine, and renders the result as cards.
struct PersonalInsightsView: View {
    @Query(filter: #Predicate<Workout> { !$0.isTemplate && $0.endTime != nil },
           sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]
    @Query(sort: \CardioSession.date, order: .reverse)
    private var cardioSessions: [CardioSession]
    @Query(sort: \CaffeineEntry.date, order: .reverse)
    private var caffeineEntries: [CaffeineEntry]
    @Query(sort: \BodyWeightEntry.date, order: .reverse)
    private var bodyWeights: [BodyWeightEntry]
    @Query(sort: \TrainingBlock.startDate, order: .reverse)
    private var trainingBlocks: [TrainingBlock]
    @Query(sort: \SorenessEntry.date, order: .reverse)
    private var sorenessReports: [SorenessEntry]
    @Query(sort: \PlanComplianceEvent.day, order: .reverse)
    private var complianceEvents: [PlanComplianceEvent]
    @Query private var settingsArray: [UserSettings]

    @State private var insights: [Insight] = []
    @State private var isLoading = true
    @State private var hasLoadedOnce = false

    private var healthKitEnabled: Bool {
        settingsArray.first?.healthKitEnabled ?? false
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                if isLoading && !hasLoadedOnce {
                    loadingState
                } else if insights.isEmpty {
                    if let summary = complianceSummary {
                        // Even with no patterns yet, we can surface the
                        // user's relationship with the engine itself.
                        complianceCard(summary)
                    }
                    emptyState
                } else {
                    headerCard
                    if let summary = complianceSummary {
                        complianceCard(summary)
                    }
                    ForEach(insights) { insight in
                        InsightCardView(insight: insight)
                    }
                    footerCard
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .task {
            await loadInsights()
        }
        .refreshable {
            await loadInsights()
        }
    }

    // MARK: - Cards

    // MARK: - Plan compliance
    //
    // Surfaces how often the user follows the engine's recommendations.
    // The engine uses this internally to downgrade confidence; making
    // it visible here closes the loop so users understand why their
    // plan card's confidence rating moves.

    private var complianceSummary: TodayPlanEngine.ComplianceSummary? {
        TodayPlanEngine.recentCompliance(events: complianceEvents)
    }

    private func complianceCard(_ summary: TodayPlanEngine.ComplianceSummary) -> some View {
        let pct = Int((summary.rate * 100).rounded())
        let followed = Int((Double(summary.sampleSize) * summary.rate).rounded())
        let tint: Color = summary.rate >= 0.7
            ? AppTheme.Signal.recovery
            : (summary.rate >= 0.5 ? AppTheme.Signal.caution : AppTheme.Signal.strain)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(tint.opacity(0.15)).frame(width: 44, height: 44)
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

            // Progress bar
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
        // Merge the icon + title + subtitle + percent + progress + footer
        // into one VoiceOver stop so the card reads as a single "plan
        // compliance: 65 percent, followed 5 of 7 plans" rather than five
        // separate focusable elements.
        .accessibilityElement(children: .combine)
    }

    private func mostIgnoredLine(for kind: TodayPlan.Intensity, count: Int) -> String {
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

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
        .accessibilityElement(children: .combine)
    }

    private var footerCard: some View {
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

    /// Adopts the canonical `EmptyStateView` primitive — the previous
    /// hand-rolled version skipped the shared accessibility merging and
    /// drifted from the design used on every other "no data yet" screen.
    private var emptyState: some View {
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

    private var loadingState: some View {
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

    // MARK: - Loading

    private func loadInsights() async {
        isLoading = true
        defer {
            isLoading = false
            hasLoadedOnce = true
        }

        var inputs = PersonalInsightsEngine.Inputs(
            workouts: workouts,
            cardioSessions: cardioSessions,
            caffeine: caffeineEntries,
            bodyWeights: bodyWeights,
            trainingBlocks: trainingBlocks,
            sorenessReports: sorenessReports
        )

        if healthKitEnabled {
            let hk = HealthDataCache.shared
            async let sleep = hk.fetchDailySleep(days: 90)
            async let hrv   = hk.fetchDailyHRV(days: 90)
            async let rhr   = hk.fetchDailyRestingHeartRate(days: 90)

            inputs.sleepByDay = (try? await sleep) ?? []
            inputs.hrvByDay   = (try? await hrv) ?? []
            inputs.rhrByDay   = (try? await rhr) ?? []
        }

        let result = PersonalInsightsEngine.generate(inputs)
        InsightsStore.save(result)
        await MainActor.run {
            self.insights = result
        }
    }
}
