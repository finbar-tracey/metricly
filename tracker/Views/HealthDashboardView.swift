import SwiftUI
import SwiftData

struct HealthDashboardView: View {
    @Environment(\.appServices) private var appServices
    @Query private var settingsArray: [UserSettings]

    @State private var todaySteps: Double = 0
    @State private var restingHR: Double?
    @State private var hrStats: (min: Double, max: Double, avg: Double)?
    @State private var sleepMinutes: Double = 0
    @State private var sleepInBed: Date?
    @State private var sleepWakeUp: Date?
    @State private var activeCalories: Double = 0
    @State private var hrv: Double?
    @State private var vo2Max: Double?
    @State private var isLoading = true

    private var healthKitEnabled: Bool { settingsArray.first?.healthKitEnabled ?? false }

    var body: some View {
        Group {
            if !healthKitEnabled {
                HealthDashboardSections.disabledView()
            } else {
                healthContent
            }
        }
        .navigationTitle("Health")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard healthKitEnabled else { return }
            await loadHealthData()
        }
        .refreshable { await loadHealthData() }
    }

    private var healthContent: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                if isLoading {
                    LoadingStateView("Loading health data…")
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    HealthDashboardSections.summaryGrid(
                        todaySteps: todaySteps,
                        restingHR: restingHR,
                        sleepMinutes: sleepMinutes,
                        activeCalories: activeCalories
                    )
                    HealthDashboardSections.vitalsCard(hrv: hrv, vo2Max: vo2Max, hrStats: hrStats)
                    HealthDashboardSections.detailLinksCard()
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func loadHealthData() async {
        isLoading = true
        defer { isLoading = false }
        let hk = appServices.healthDataCache
        let today = Date.now

        async let stepsResult = hk.fetchSteps(for: today)
        async let hrResult = hk.fetchRestingHeartRate(for: today)
        async let hrStatsResult = hk.fetchHeartRateStats(for: today)
        async let sleepResult = hk.fetchSleep(for: today)
        async let caloriesResult = hk.fetchActiveEnergy(for: today)
        async let hrvResult = hk.fetchHRV(for: today)
        async let vo2Result = hk.fetchLatestVO2Max()

        todaySteps = (try? await stepsResult) ?? 0
        restingHR = try? await hrResult
        hrStats = try? await hrStatsResult
        let sleep = try? await sleepResult
        sleepMinutes = sleep?.totalMinutes ?? 0
        sleepInBed = sleep?.inBed
        sleepWakeUp = sleep?.wakeUp
        activeCalories = (try? await caloriesResult) ?? 0
        hrv = try? await hrvResult
        vo2Max = try? await vo2Result
    }
}
