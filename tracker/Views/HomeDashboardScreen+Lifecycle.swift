import SwiftUI
import SwiftData

extension HomeDashboardScreen {

    var homeScrollContent: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                HomeDashboardTopSection(
                    snapshot: snapshot,
                    store: store,
                    greeting: greeting,
                    healthKitEnabled: healthKitEnabled,
                    healthDataLoaded: healthDataLoaded,
                    hrv: hrv,
                    sleepMinutes: sleepMinutes,
                    restingHR: restingHR,
                    animateRings: animateRings,
                    heroGradientColors: heroGradientColors,
                    topInsight: topInsight,
                    shouldOfferInsightsTease: shouldOfferInsightsTease,
                    ctaKind: ctaKind,
                    todaySteps: todaySteps,
                    activeCalories: activeCalories,
                    weightUnit: weightUnit,
                    tappedDayWorkout: $tappedDayWorkout,
                    blockForDetailSheet: $blockForDetailSheet,
                    showingAddWorkout: $showingAddWorkout,
                    onPlanDetail: { homeRoute = .planDetail },
                    onInsertBlock: { newBlock in
                        modelContext.insert(newBlock)
                        try? modelContext.save()
                        onRefreshSnapshot()
                        onRecompute(liveHealthSignals, externalWorkouts)
                    },
                    onOpenInsights: { appServices.router.openInsightsTab() }
                )
                momentumCard
                HomeDashboardMiddleSection(
                    snapshot: snapshot,
                    store: store,
                    healthKitEnabled: healthKitEnabled,
                    healthDataLoaded: healthDataLoaded,
                    weightUnit: weightUnit,
                    totalCaffeineMg: totalCaffeineMg(at: .now),
                    suggestedBedtime: suggestedBedtime(from: .now),
                    caffeineClearTime: caffeineClearTime(from: .now)
                )
                HomeDashboardBottomSection(
                    snapshot: snapshot,
                    healthKitEnabled: healthKitEnabled,
                    healthDataLoaded: healthDataLoaded,
                    animateRings: animateRings,
                    todaySteps: todaySteps,
                    sleepMinutes: sleepMinutes,
                    restingHR: restingHR,
                    hrv: hrv,
                    activeCalories: activeCalories,
                    totalCaffeineMg: totalCaffeineMg(at: .now),
                    progressionSuggestions: cachedProgressionSuggestions,
                    weightUnit: weightUnit,
                    showingAddWorkout: $showingAddWorkout
                )
            }
            .padding(.horizontal)
            .padding(.bottom, 36)
        }
    }

    @ViewBuilder
    func homeDashboardChrome<Content: View>(_ content: Content) -> some View {
        content
            .tabBackground(tint: heroGradientColors.first ?? .accentColor, height: 420)
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        if let lastWorkout = snapshot.allWorkouts.first, !lastWorkout.exercises.isEmpty {
                            Button { repeatConfirmation = true } label: {
                                Label("Repeat Last", systemImage: "arrow.counterclockwise")
                            }
                        }
                        Button { showingAddWorkout = true } label: {
                            Label("Add Workout", systemImage: "plus")
                        }
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                onQuickStart()
                            }
                        )
                        .accessibilityHint("Long press to start a workout with today's plan applied automatically.")
                    }
                }
            }
            .sheet(isPresented: $showingAddWorkout) {
                AddWorkoutSheet().environment(\.weightUnit, weightUnit)
            }
            .sheet(item: $blockForDetailSheet) { block in
                TrainingBlockDetailView(block: block, allBlocks: snapshot.trainingBlocks)
                    .onDisappear {
                        onRefreshSnapshot()
                        onRecompute(liveHealthSignals, externalWorkouts)
                    }
            }
            .navigationDestination(item: $tappedDayWorkout) { workout in
                WorkoutDetailView(workout: workout)
            }
            .navigationDestination(item: $homeRoute) { route in
                switch route {
                case .planDetail:
                    TodayPlanDetailView(
                        plan: store.todayPlan,
                        recovery: store.recoveryResult,
                        health: liveHealthSignals
                    )
                }
            }
            .confirmationDialog("Repeat your last workout?", isPresented: $repeatConfirmation) {
                Button("Repeat \"\(snapshot.allWorkouts.first?.name ?? "")\"") { onRepeatLast() }
            } message: {
                Text("This will create a new workout with the same exercises (no sets copied).")
            }
            .onAppear {
                onRefreshSnapshot()
                onBuildProgression($cachedProgressionSuggestions)
                onRecompute(liveHealthSignals, externalWorkouts)
                topInsight = InsightsStore.load()?.first
                if store.recoveryResult.readinessScore < 0.40 {
                    ReminderManager.scheduleRecoveryRestReminder()
                }
            }
            .onChange(of: snapshot.allWorkouts.count) {
                onBuildProgression($cachedProgressionSuggestions)
            }
            .onChange(of: snapshot.finishedWorkouts.count) {
                onRecompute(liveHealthSignals, externalWorkouts)
            }
            .onChange(of: snapshot.cardioSessions.count) {
                onRecompute(liveHealthSignals, externalWorkouts)
            }
            .onChange(of: healthDataLoaded) {
                onRecompute(liveHealthSignals, externalWorkouts)
            }
            .task {
                guard healthKitEnabled else { return }
                await loadHealthData()
                onRecompute(liveHealthSignals, externalWorkouts)
                withAnimation(.easeOut(duration: 0.8)) { animateRings = true }
            }
            .refreshable {
                if healthKitEnabled {
                    animateRings = false
                    await loadHealthData()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.easeOut(duration: 0.8)) { animateRings = true }
                }
            }
    }

    var heroGradientColors: [Color] {
        guard healthKitEnabled && healthDataLoaded else {
            return AppTheme.Gradients.calm
        }
        let score = store.recoveryResult.readinessScore
        if score >= 0.70 { return AppTheme.Gradients.recovery }
        if score >= 0.45 { return AppTheme.Gradients.caution }
        return AppTheme.Gradients.strain
    }

    var shouldOfferInsightsTease: Bool {
        guard topInsight == nil else { return false }
        let finished = snapshot.allWorkouts.lazy.filter { !$0.isTemplate && $0.endTime != nil }
        return finished.prefix(5).count >= 5
    }

    var ctaKind: HomeContextualCTASection.Kind? {
        if let active = snapshot.inProgressWorkout { return .continueWorkout(active) }
        if !snapshot.todaysWorkouts.isEmpty && snapshot.todaysWorkouts.allSatisfy(\.isFinished) {
            return .greatSession(totalSets: snapshot.todayTotalSets, totalVolumeKg: snapshot.todayTotalVolumeKg)
        }
        return nil
    }

    func loadHealthData() async {
        let hk = appServices.healthDataCache
        let today = Date.now
        async let stepsResult = hk.fetchSteps(for: today)
        async let hrResult = hk.fetchRestingHeartRate(for: today)
        async let sleepResult = hk.fetchSleep(for: today)
        async let caloriesResult = hk.fetchActiveEnergy(for: today)
        async let hrvResult = hk.fetchHRV(for: today)
        async let hrvHistoryResult = hk.fetchDailyHRV(days: 7)
        async let rhrHistoryResult = hk.fetchDailyRestingHeartRate(days: 7)
        async let externalResult = hk.fetchExternalWorkouts(days: 7)

        todaySteps = (try? await stepsResult) ?? 0
        restingHR = try? await hrResult
        sleepMinutes = (try? await sleepResult)?.totalMinutes ?? 0
        activeCalories = (try? await caloriesResult) ?? 0
        hrv = try? await hrvResult

        if let hrvHistory = try? await hrvHistoryResult, !hrvHistory.isEmpty {
            averageHRV = hrvHistory.map(\.ms).reduce(0, +) / Double(hrvHistory.count)
        }
        if let rhrHistory = try? await rhrHistoryResult, !rhrHistory.isEmpty {
            averageRestingHR = rhrHistory.map(\.bpm).reduce(0, +) / Double(rhrHistory.count)
        }
        externalWorkouts = (try? await externalResult) ?? []
        healthDataLoaded = true
    }
}
