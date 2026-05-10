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
                    emptyState
                } else {
                    headerCard
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

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Personal patterns")
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Text("Trends spotted in your training, sleep and recovery data over the last 90 days. These are observations, not medical advice.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private var footerCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
            Text("Patterns improve as you log more data. Most insights need 90+ days and 8+ matching sessions before they appear.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.tertiary)
            Text("Not enough data yet")
                .font(.subheadline.weight(.semibold))
            Text("Keep logging workouts and connecting Health data — we'll surface patterns as soon as we have enough to compare.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
        .appCard()
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
            Text("Looking for patterns…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
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
            bodyWeights: bodyWeights
        )

        if healthKitEnabled {
            let hk = HealthKitManager.shared
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
