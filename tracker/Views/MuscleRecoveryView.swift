import SwiftUI
import SwiftData

struct MuscleRecoveryView: View {
    @Query(filter: #Predicate<Workout> { !$0.isTemplate && $0.endTime != nil },
           sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]
    @Query private var settingsArray: [UserSettings]
    @Query(sort: \CardioSession.date, order: .reverse) private var cardioSessions: [CardioSession]
    @Query(sort: \SorenessEntry.date, order: .reverse) private var sorenessReports: [SorenessEntry]
    @Environment(\.appServices) private var appServices
    @Environment(\.weightUnit) private var weightUnit

    @State private var lastNightSleep: Double = 0
    @State private var latestHRV: Double?
    @State private var averageHRV: Double?
    @State private var todayRestingHR: Double?
    @State private var averageRestingHR: Double?
    @State private var healthDataLoaded = false
    @State private var externalWorkouts: [ExternalWorkout] = []
    @State private var recoveryResult: RecoveryResult = .empty

    private var activeSorenessReports: [SorenessEntry] {
        MuscleRecoverySections.activeSorenessReports(from: sorenessReports)
    }

    private func recomputeRecovery() {
        recoveryResult = RecoveryEngine.evaluate(
            workouts: workouts,
            health: HealthSignals(
                todayHRV: latestHRV,
                averageHRV: averageHRV,
                todayRestingHR: todayRestingHR,
                averageRestingHR: averageRestingHR,
                sleepMinutes: healthDataLoaded ? lastNightSleep : nil
            ),
            externalWorkouts: externalWorkouts,
            cardioSessions: Array(cardioSessions.prefix(50)),
            sorenessReports: Array(sorenessReports.prefix(30))
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                MuscleRecoverySections.heroCard(
                    recoveryResult: recoveryResult,
                    healthDataLoaded: healthDataLoaded,
                    lastNightSleep: lastNightSleep,
                    latestHRV: latestHRV,
                    averageHRV: averageHRV,
                    todayRestingHR: todayRestingHR,
                    averageRestingHR: averageRestingHR
                )
                if !externalWorkouts.isEmpty {
                    MuscleRecoverySections.externalActivityCard(
                        externalWorkouts: externalWorkouts,
                        weightUnit: weightUnit
                    )
                }
                if !activeSorenessReports.isEmpty {
                    MuscleRecoverySections.sorenessReportsCard(
                        activeSorenessReports: activeSorenessReports
                    )
                }
                MuscleRecoverySections.muscleGroupsCard(recoveryResult: recoveryResult)
                MuscleRecoverySections.suggestedCard(recoveryResult: recoveryResult)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(String(
            localized: "Recovery",
            comment: "Navigation title for the muscle recovery / readiness screen"
        ))
        .task {
            guard settingsArray.first?.healthKitEnabled == true else { return }
            let hk = appServices.healthDataCache
            async let hrvResult = hk.fetchHRV(for: .now)
            async let hrvHistoryResult = hk.fetchDailyHRV(days: 7)
            async let sleepResult = hk.fetchSleep(for: .now)
            async let rhrResult = hk.fetchRestingHeartRate(for: .now)
            async let rhrHistoryResult = hk.fetchDailyRestingHeartRate(days: 7)
            async let externalResult = hk.fetchExternalWorkouts(days: 7)
            latestHRV = try? await hrvResult
            let hrvHistory = (try? await hrvHistoryResult) ?? []
            if !hrvHistory.isEmpty { averageHRV = hrvHistory.map(\.ms).reduce(0, +) / Double(hrvHistory.count) }
            let sleep = try? await sleepResult
            lastNightSleep = sleep?.totalMinutes ?? 0
            todayRestingHR = try? await rhrResult
            let rhrHistory = (try? await rhrHistoryResult) ?? []
            if !rhrHistory.isEmpty { averageRestingHR = rhrHistory.map(\.bpm).reduce(0, +) / Double(rhrHistory.count) }
            externalWorkouts = (try? await externalResult) ?? []
            healthDataLoaded = true
            recomputeRecovery()
        }
        .onChange(of: workouts) { recomputeRecovery() }
        .onChange(of: cardioSessions) { recomputeRecovery() }
        .onChange(of: sorenessReports) { recomputeRecovery() }
    }
}

#Preview {
    NavigationStack { MuscleRecoveryView() }
        .modelContainer(for: Workout.self, inMemory: true)
}
