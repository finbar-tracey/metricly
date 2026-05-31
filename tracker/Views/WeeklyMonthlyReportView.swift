import SwiftUI
import SwiftData

struct WeeklyMonthlyReportView: View {
    @Query(filter: #Predicate<Workout> { !$0.isTemplate }, sort: \Workout.date, order: .reverse)
    private var allWorkouts: [Workout]
    @Query(sort: \CardioSession.date, order: .reverse) private var cardioSessions: [CardioSession]
    @Query(sort: \BodyWeightEntry.date) private var allBodyWeightEntries: [BodyWeightEntry]
    @Query private var settingsArray: [UserSettings]
    @Environment(\.appServices) private var appServices
    @Environment(\.weightUnit) private var weightUnit

    @State private var selectedPeriod: ReportPeriod = .week
    @State private var showingShare = false
    @State private var shareImage: UIImage?

    @State private var avgSteps: Double?
    @State private var avgSleepMinutes: Double?
    @State private var avgRestingHR: Double?
    @State private var avgHRV: Double?
    @State private var prevAvgSteps: Double?
    @State private var prevAvgSleepMinutes: Double?
    @State private var prevAvgRestingHR: Double?
    @State private var prevAvgHRV: Double?
    @State private var isLoadingHealth = false

    private var snapshot: WeeklyMonthlyReportSnapshot {
        WeeklyMonthlyReportEngine.make(
            WeeklyMonthlyReportEngine.Inputs(
                period: selectedPeriod,
                allWorkouts: allWorkouts,
                cardioSessions: cardioSessions,
                bodyWeightEntries: allBodyWeightEntries,
                resolvedMaxHR: Double(settingsArray.first?.resolvedMaxHR ?? 190)
            )
        )
    }

    private var displayVolume: Double { weightUnit.display(snapshot.totalVolumeKg) }
    private var healthKitEnabled: Bool { settingsArray.first?.healthKitEnabled ?? false }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                WeeklyMonthlyReportSections.periodPickerCard(selectedPeriod: $selectedPeriod)
                WeeklyMonthlyReportSections.heroCard(snapshot: snapshot, displayVolume: displayVolume, weightUnit: weightUnit)
                WeeklyMonthlyReportSections.trainingSummaryCard(snapshot: snapshot, displayVolume: displayVolume, weightUnit: weightUnit)

                if snapshot.cardioCount > 0 {
                    WeeklyMonthlyReportSections.cardioCard(snapshot: snapshot, weightUnit: weightUnit)
                }
                if snapshot.prsHitCount > 0 {
                    WeeklyMonthlyReportSections.prsCard(snapshot: snapshot)
                }
                if !snapshot.muscleGroupSetCounts.isEmpty {
                    WeeklyMonthlyReportSections.muscleGroupsCard(snapshot: snapshot)
                }
                if snapshot.periodBodyWeightEntries.count >= 2 {
                    WeeklyMonthlyReportSections.bodyWeightCard(snapshot: snapshot, weightUnit: weightUnit)
                }
                if healthKitEnabled {
                    WeeklyMonthlyReportSections.healthSummaryCard(
                        avgSteps: avgSteps,
                        avgSleepMinutes: avgSleepMinutes,
                        avgRestingHR: avgRestingHR,
                        avgHRV: avgHRV,
                        prevAvgSteps: prevAvgSteps,
                        prevAvgSleepMinutes: prevAvgSleepMinutes,
                        prevAvgRestingHR: prevAvgRestingHR,
                        prevAvgHRV: prevAvgHRV,
                        isLoadingHealth: isLoadingHealth
                    )
                }
                WeeklyMonthlyReportSections.consistencyCard(snapshot: snapshot)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Report")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { shareAsImage() } label: { Image(systemName: "square.and.arrow.up") }
                    .disabled(snapshot.periodWorkoutsEmpty)
                    .accessibilityLabel("Share report")
            }
        }
        .sheet(isPresented: $showingShare) {
            if let image = shareImage { ShareSheet(items: [image]) }
        }
        .task(id: selectedPeriod) {
            guard healthKitEnabled else { return }
            await loadHealthData()
        }
        .onChange(of: selectedPeriod) { _, _ in
            avgSteps = nil; avgSleepMinutes = nil; avgRestingHR = nil; avgHRV = nil
            prevAvgSteps = nil; prevAvgSleepMinutes = nil; prevAvgRestingHR = nil; prevAvgHRV = nil
        }
    }

    private func loadHealthData() async {
        isLoadingHealth = true
        defer { isLoadingHealth = false }
        let hk = appServices.healthDataCache
        let days: Int = selectedPeriod == .week ? 14 : 60
        let range = snapshot.currentRange
        let prevRange = snapshot.previousRange

        async let stepsResult = hk.fetchDailySteps(days: days)
        async let sleepResult = hk.fetchDailySleep(days: days)
        async let hrResult = hk.fetchDailyRestingHeartRate(days: days)
        async let hrvResult = hk.fetchDailyHRV(days: days)

        if let steps = try? await stepsResult {
            let current = steps.filter { $0.date >= range.start }
            avgSteps = current.isEmpty ? nil : current.map(\.steps).reduce(0, +) / Double(current.count)
            let prev = steps.filter { $0.date >= prevRange.start && $0.date < prevRange.end }
            prevAvgSteps = prev.isEmpty ? nil : prev.map(\.steps).reduce(0, +) / Double(prev.count)
        }
        if let sleep = try? await sleepResult {
            let current = sleep.filter { $0.date >= range.start }
            avgSleepMinutes = current.isEmpty ? nil : current.map(\.minutes).reduce(0, +) / Double(current.count)
            let prev = sleep.filter { $0.date >= prevRange.start && $0.date < prevRange.end }
            prevAvgSleepMinutes = prev.isEmpty ? nil : prev.map(\.minutes).reduce(0, +) / Double(prev.count)
        }
        if let hr = try? await hrResult {
            let current = hr.filter { $0.date >= range.start }
            avgRestingHR = current.isEmpty ? nil : current.map(\.bpm).reduce(0, +) / Double(current.count)
            let prev = hr.filter { $0.date >= prevRange.start && $0.date < prevRange.end }
            prevAvgRestingHR = prev.isEmpty ? nil : prev.map(\.bpm).reduce(0, +) / Double(prev.count)
        }
        if let hrv = try? await hrvResult {
            let current = hrv.filter { $0.date >= range.start }
            avgHRV = current.isEmpty ? nil : current.map(\.ms).reduce(0, +) / Double(current.count)
            let prev = hrv.filter { $0.date >= prevRange.start && $0.date < prevRange.end }
            prevAvgHRV = prev.isEmpty ? nil : prev.map(\.ms).reduce(0, +) / Double(prev.count)
        }
    }

    @MainActor
    private func shareAsImage() {
        let s = snapshot
        let shareCard = ReportShareCardView(
            periodLabel: s.periodLabel,
            selectedPeriod: s.period,
            vibeEmoji: s.vibeEmoji,
            workoutCount: s.workoutCount,
            totalSets: s.totalSets,
            totalVolume: displayVolume,
            formattedDuration: s.formattedDuration,
            volumeChange: s.volumeChange,
            prsHitCount: s.prsHitCount,
            prExerciseNames: s.prExerciseNames,
            muscleGroupSetCounts: s.muscleGroupSetCounts,
            bodyWeightStart: s.bodyWeightStart,
            bodyWeightEnd: s.bodyWeightEnd,
            bodyWeightChange: s.bodyWeightChange,
            avgSteps: avgSteps,
            avgSleepMinutes: avgSleepMinutes,
            avgRestingHR: avgRestingHR,
            avgHRV: avgHRV,
            currentStreak: s.currentStreak,
            cardioCount: s.cardioCount,
            cardioDistanceText: weightUnit.distanceUnit.format(s.cardioDistanceKm),
            weightUnit: weightUnit
        )
        let renderer = ImageRenderer(content:
            shareCard.frame(width: 380).padding(16).background(Color(.systemGroupedBackground))
        )
        renderer.scale = 3.0
        if let image = renderer.uiImage { shareImage = image; showingShare = true }
    }
}

#Preview {
    NavigationStack { WeeklyMonthlyReportView() }
        .modelContainer(for: Workout.self, inMemory: true)
}
