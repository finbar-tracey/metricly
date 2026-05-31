import SwiftUI
import SwiftData

/// "Patterns" view inside the Insights tab — shows correlation-based insights
/// from `PersonalInsightsEngine`. Pulls 90 days of HealthKit history on first
/// appear, runs the engine, and renders the result as cards.
struct PersonalInsightsView: View {
    @Environment(\.appServices) private var appServices
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

    private var complianceSummary: TodayPlanEngine.ComplianceSummary? {
        TodayPlanEngine.recentCompliance(events: complianceEvents)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                if isLoading && !hasLoadedOnce {
                    PersonalInsightsSections.loadingState()
                } else if insights.isEmpty {
                    if let summary = complianceSummary {
                        PersonalInsightsSections.complianceCard(summary)
                    }
                    PersonalInsightsSections.emptyState()
                } else {
                    PersonalInsightsSections.headerCard()
                    if let summary = complianceSummary {
                        PersonalInsightsSections.complianceCard(summary)
                    }
                    ForEach(insights) { insight in
                        InsightCardView(insight: insight)
                    }
                    PersonalInsightsSections.footerCard()
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
            let hk = appServices.healthDataCache
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
