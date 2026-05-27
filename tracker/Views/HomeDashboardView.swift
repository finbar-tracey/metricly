import SwiftUI
import SwiftData

struct HomeDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Workout> { $0.isTemplate }, sort: \Workout.name)
    private var templates: [Workout]
    @Query(filter: #Predicate<Workout> { !$0.isTemplate && $0.endTime != nil }, sort: \Workout.date, order: .reverse)
    private var finishedWorkouts: [Workout]
    @Query(filter: #Predicate<Workout> { !$0.isTemplate }, sort: \Workout.date, order: .reverse)
    private var allWorkouts: [Workout]
    @Query private var settingsArray: [UserSettings]
    @Query(sort: \CaffeineEntry.date, order: .reverse) private var caffeineEntries: [CaffeineEntry]
    @Query(sort: \WaterEntry.date, order: .reverse) private var waterEntries: [WaterEntry]
    @Query(sort: \CreatineEntry.date, order: .reverse) private var creatineEntries: [CreatineEntry]
    @Query(sort: \CardioSession.date, order: .reverse) private var cardioSessions: [CardioSession]
    @Query(sort: \SorenessEntry.date, order: .reverse) private var sorenessReports: [SorenessEntry]
    @Query(sort: \PlanComplianceEvent.day, order: .reverse) private var complianceEvents: [PlanComplianceEvent]
    @Environment(\.weightUnit) private var weightUnit

    @State private var todaySteps: Double = 0
    @State private var restingHR: Double?
    @State private var sleepMinutes: Double = 0
    @State private var hrv: Double?
    @State private var averageHRV: Double?
    @State private var activeCalories: Double = 0
    @State private var averageRestingHR: Double?
    @State private var healthDataLoaded = false
    @State private var externalWorkouts: [ExternalWorkout] = []
    @State private var animateRings = false
    @State private var showingAddWorkout = false
    @State private var showingPlanDetail = false
    @State private var topInsight: Insight?
    @State private var repeatConfirmation = false
    @State private var tappedDayWorkout: Workout?
    @State private var cachedProgressionSuggestions: [ProgressionSuggestion] = []

    // MARK: - Caffeine Helpers (thin wrappers over CaffeineEngine)

    private func totalCaffeineMg(at time: Date) -> Double {
        CaffeineEngine.totalMg(at: time, entries: caffeineEntries, halfLifeHours: settings.caffeineHalfLife)
    }

    private func caffeineClearTime(from now: Date) -> Date? {
        CaffeineEngine.clearTime(from: now, entries: caffeineEntries, halfLifeHours: settings.caffeineHalfLife)
    }

    private func suggestedBedtime(from now: Date) -> (time: Date, delayedByCaffeine: Bool) {
        CaffeineEngine.suggestedBedtime(from: now, entries: caffeineEntries, halfLifeHours: settings.caffeineHalfLife)
    }

    // MARK: - Water / Creatine Helpers

    private var waterGoalMl: Double { Double(settings.dailyWaterGoalMl) }

    private var todayWaterMl: Double {
        let start = Calendar.current.startOfDay(for: .now)
        return waterEntries.filter { $0.date >= start }.reduce(0) { $0 + $1.milliliters }
    }

    private var waterProgress: Double { waterGoalMl > 0 ? min(1.0, todayWaterMl / waterGoalMl) : 0 }

    private var creatineTakenToday: Bool {
        creatineEntries.contains { $0.date >= Calendar.current.startOfDay(for: .now) }
    }

    // MARK: - Computed Helpers

    private var settings: UserSettings { settingsArray.first ?? UserSettings() }
    private var healthKitEnabled: Bool { settingsArray.first?.healthKitEnabled ?? false }

    private var activitiesThisWeek: Int {
        guard let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start else { return 0 }
        let workoutCount = allWorkouts.filter { $0.date >= weekStart }.count
        let cardioCount  = cardioSessions.filter { $0.date >= weekStart }.count
        return workoutCount + cardioCount
    }

    private var currentStreak: Int { Workout.currentStreak(from: allWorkouts, cardioSessions: Array(cardioSessions.prefix(60))) }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let name = settings.userName.isEmpty ? nil : settings.userName
        let timeGreeting: String
        switch hour {
        case 5..<12: timeGreeting = "Good morning"
        case 12..<17: timeGreeting = "Good afternoon"
        default: timeGreeting = "Good evening"
        }
        return name.map { "\(timeGreeting), \($0)" } ?? timeGreeting
    }

    @State private var recoveryResult: RecoveryResult = .empty
    @State private var todayPlan: TodayPlan = .empty

    private var liveHealthSignals: HealthSignals {
        HealthSignals(
            todayHRV: hrv, averageHRV: averageHRV,
            todayRestingHR: restingHR, averageRestingHR: averageRestingHR,
            sleepMinutes: healthDataLoaded ? sleepMinutes : nil
        )
    }

    private func recomputeRecoveryAndPlan() {
        let recovery = RecoveryEngine.evaluate(
            workouts: finishedWorkouts,
            health: liveHealthSignals,
            externalWorkouts: externalWorkouts,
            cardioSessions: Array(cardioSessions.prefix(50)),
            sorenessReports: Array(sorenessReports.prefix(30))
        )
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .distantPast
        let recent = finishedWorkouts.filter { $0.date >= twoWeeksAgo }
        let plan = TodayPlanEngine.generate(
            scheduledName: settings.weeklyPlan[todayWeekday],
            recovery: recovery,
            health: liveHealthSignals,
            recentWorkouts: recent,
            alreadyTrainedToday: !todaysWorkouts.filter(\.isFinished).isEmpty
                || cardioSessions.contains { Calendar.current.isDateInToday($0.date) },
            hasAnyHistory: !finishedWorkouts.isEmpty,
            complianceEvents: Array(complianceEvents.prefix(14))
        )
        self.recoveryResult = recovery
        self.todayPlan = plan
        TodayPlanStore.save(plan)
    }

    private var averageRating: Double? {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .distantPast
        let rated = allWorkouts.filter { $0.date >= weekAgo && ($0.rating ?? 0) > 0 }
        guard !rated.isEmpty else { return nil }
        return Double(rated.compactMap(\.rating).reduce(0, +)) / Double(rated.count)
    }

    private var todaysWorkouts: [Workout] {
        allWorkouts.filter { $0.date >= Calendar.current.startOfDay(for: .now) }
    }

    private var todayTotalSets: Int {
        todaysWorkouts.reduce(0) { $0 + $1.exercises.reduce(0) { $0 + $1.sets.filter { !$0.isWarmUp }.count } }
    }

    private var todayTotalVolumeKg: Double {
        todaysWorkouts.reduce(0.0) { $0 + $1.totalVolumeKg() }
    }

    private var todayMuscleGroups: [MuscleGroup] {
        Array(Set(todaysWorkouts.flatMap { $0.exercises.compactMap(\.category) })).sorted { $0.rawValue < $1.rawValue }
    }

    private var inProgressWorkout: Workout? { allWorkouts.first { !$0.isFinished } }

    private var todayWeekday: Int {
        Calendar.current.component(.weekday, from: .now)
    }

    private struct ProgressionSuggestion: Identifiable {
        let id = UUID()
        let exerciseName: String
        let recommendation: ProgressionRecommendation
    }

    private func buildProgressionSuggestions() {
        // Snapshot the data we need on the main thread, then compute off it.
        let snapshot = allWorkouts
        Task(priority: .utility) {
            let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .distantPast
            let recentWorkouts = snapshot.filter { $0.endTime != nil && $0.date >= twoWeeksAgo }
            var seen = Set<String>(); var exerciseNames: [String] = []
            for workout in recentWorkouts {
                for exercise in workout.exercises {
                    let key = exercise.name.lowercased()
                    if !seen.contains(key) { seen.insert(key); exerciseNames.append(exercise.name) }
                }
            }
            var suggestions: [ProgressionSuggestion] = []
            let allExercisesFlat = snapshot.flatMap(\.exercises)
            for name in exerciseNames {
                let history = allExercisesFlat
                    .filter { $0.name.lowercased() == name.lowercased() && !(($0.workout?.isTemplate) ?? true) && !$0.sets.isEmpty }
                    .sorted { ($0.workout?.date ?? .distantPast) > ($1.workout?.date ?? .distantPast) }
                let sessions = ProgressionAdvisor.buildSessions(from: history)
                guard sessions.count >= 2 else { continue }
                let rec = ProgressionAdvisor.recommend(sessions: sessions, muscleGroup: history.first?.category)
                if case .increase = rec.action {
                    suggestions.append(ProgressionSuggestion(exerciseName: name, recommendation: rec))
                }
            }
            let result = Array(suggestions.sorted { $0.recommendation.confidence > $1.recommendation.confidence }.prefix(3))
            await MainActor.run { cachedProgressionSuggestions = result }
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                topSection
                middleSection
                bottomSection
            }
            .padding(.horizontal)
            .padding(.bottom, 36)
        }
        .tabBackground(tint: heroGradientColors.first ?? .accentColor, height: 420)
        .navigationTitle("Home")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    if let lastWorkout = allWorkouts.first, !lastWorkout.exercises.isEmpty {
                        Button { repeatConfirmation = true } label: {
                            Label("Repeat Last", systemImage: "arrow.counterclockwise")
                        }
                    }
                    Button { showingAddWorkout = true } label: {
                        Label("Add Workout", systemImage: "plus")
                    }
                    // Long-press to skip the sheet and start with smart
                    // defaults — useful when you've already decided what
                    // today's plan is and just want to begin.
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            quickStartWorkout()
                        }
                    )
                    .accessibilityHint("Long press to start a workout with today's plan applied automatically.")
                }
            }
        }
        .sheet(isPresented: $showingAddWorkout) {
            AddWorkoutSheet().environment(\.weightUnit, weightUnit)
        }
        .navigationDestination(item: $tappedDayWorkout) { workout in
            WorkoutDetailView(workout: workout)
        }
        .navigationDestination(isPresented: $showingPlanDetail) {
            TodayPlanDetailView(
                plan: todayPlan,
                recovery: recoveryResult,
                health: liveHealthSignals
            )
        }
        .confirmationDialog("Repeat your last workout?", isPresented: $repeatConfirmation) {
            Button("Repeat \"\(allWorkouts.first?.name ?? "")\"") { repeatLastWorkout() }
        } message: {
            Text("This will create a new workout with the same exercises (no sets copied).")
        }
        .onAppear {
            buildProgressionSuggestions()
            recomputeRecoveryAndPlan()
            // Pull the most-recent top insight from the cache populated by
            // PersonalInsightsView. We don't recompute here — that's expensive
            // and happens when the user actually visits the Patterns tab.
            topInsight = InsightsStore.load()?.first
            if recoveryResult.readinessScore < 0.40 {
                ReminderManager.scheduleRecoveryRestReminder()
            }
        }
        .onChange(of: allWorkouts.count) { buildProgressionSuggestions() }
        .onChange(of: finishedWorkouts.count) { recomputeRecoveryAndPlan() }
        .onChange(of: cardioSessions.count) { recomputeRecoveryAndPlan() }
        .onChange(of: healthDataLoaded) { recomputeRecoveryAndPlan() }
        .task {
            guard healthKitEnabled else { return }
            await loadHealthData()
            recomputeRecoveryAndPlan()
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

    // MARK: - Hero gradient

    private var heroGradientColors: [Color] {
        guard healthKitEnabled && healthDataLoaded else {
            return AppTheme.Gradients.calm
        }
        let score = recoveryResult.readinessScore
        if score >= 0.70 {
            return AppTheme.Gradients.recovery
        } else if score >= 0.45 {
            return AppTheme.Gradients.caution
        } else {
            return AppTheme.Gradients.strain
        }
    }

    // MARK: - Body Sections
    //
    // We split the body into three sections AND type-erase each with AnyView.
    // Without erasure, every `some View` getter accumulates into one giant
    // opaque-type chain at the body root — large enough that the Swift runtime
    // metadata builder overflows the stack while demangling. AnyView breaks
    // that chain into three independent type-checking scopes.
    //
    // Most card content lives in dedicated `HomeXxxSection` files;
    // this view stays slim and acts as the state/composition root.

    private var topSection: AnyView {
        AnyView(
            VStack(spacing: AppTheme.sectionSpacing) {
                HomeHeroSection(
                    greeting: greeting,
                    healthKitEnabled: healthKitEnabled,
                    healthDataLoaded: healthDataLoaded,
                    recovery: recoveryResult,
                    hrv: hrv,
                    currentStreak: currentStreak,
                    allWorkouts: allWorkouts,
                    animateRings: animateRings,
                    gradientColors: heroGradientColors,
                    onStartWorkout: { showingAddWorkout = true },
                    onWeekDayTapped: { tappedDayWorkout = $0 }
                )
                if HomeSyncStatusPill.shouldShow {
                    HomeSyncStatusPill()
                }
                if let cta = ctaKind {
                    HomeContextualCTASection(kind: cta, weightUnit: weightUnit)
                }
                adaptivePlanCard
                if let insight = topInsight {
                    TopInsightCardView(insight: insight) {
                        NotificationCenter.default.post(name: .openInsightsTab, object: nil)
                    }
                }
                HomePlanAndMetricsRow(
                    plan: todayPlan,
                    scheduledNameForToday: settings.weeklyPlan[todayWeekday],
                    todaysWorkouts: todaysWorkouts,
                    todayTotalSets: todayTotalSets,
                    todayTotalVolumeKg: todayTotalVolumeKg,
                    weightUnit: weightUnit,
                    healthDataLoaded: healthKitEnabled && healthDataLoaded,
                    sleepMinutes: sleepMinutes,
                    restingHR: restingHR,
                    activeCalories: activeCalories,
                    todayWaterMl: todayWaterMl,
                    waterProgress: waterProgress,
                    activitiesThisWeek: activitiesThisWeek,
                    weeklyGoal: settings.weeklyGoal,
                    currentStreak: currentStreak,
                    onStartWorkout: { showingAddWorkout = true }
                )
            }
        )
    }

    /// Returns the CTA kind to show today, or nil to hide the CTA card.
    /// "Ready to train" and "Rest day" cases are surfaced inside the hero
    /// chip instead, so this only handles the in-progress / great-session
    /// states.
    private var ctaKind: HomeContextualCTASection.Kind? {
        if let active = inProgressWorkout { return .continueWorkout(active) }
        if !todaysWorkouts.isEmpty && todaysWorkouts.allSatisfy(\.isFinished) {
            return .greatSession(totalSets: todayTotalSets, totalVolumeKg: todayTotalVolumeKg)
        }
        return nil
    }

    private var middleSection: AnyView {
        AnyView(
            VStack(spacing: AppTheme.sectionSpacing) {
                if healthKitEnabled && healthDataLoaded {
                    HomeMuscleReadinessSection(recovery: recoveryResult)
                }
                if !caffeineEntries.isEmpty && totalCaffeineMg(at: .now) >= 25 {
                    let suggestion = suggestedBedtime(from: .now)
                    HomeBedtimeSuggestion(
                        bedtime: suggestion.time,
                        delayedByCaffeine: suggestion.delayedByCaffeine,
                        clearTime: caffeineClearTime(from: .now)
                    )
                }
                HomeTrainingStatusSection(
                    weeklyGoal: settings.weeklyGoal,
                    activitiesThisWeek: activitiesThisWeek,
                    currentStreak: currentStreak,
                    suggestedWorkoutType: recoveryResult.suggestedWorkoutType,
                    averageRating: averageRating
                )
                if !cardioSessions.isEmpty {
                    HomeCardioSection(sessions: Array(cardioSessions), weightUnit: weightUnit)
                }
            }
        )
    }

    private var bottomSection: AnyView {
        AnyView(
            VStack(spacing: AppTheme.sectionSpacing) {
                if !cachedProgressionSuggestions.isEmpty {
                    HomeProgressionSection(
                        suggestions: cachedProgressionSuggestions.map {
                            HomeProgressionSection.Suggestion(
                                id: $0.id,
                                exerciseName: $0.exerciseName,
                                recommendation: $0.recommendation
                            )
                        },
                        weightUnit: weightUnit
                    )
                }
                if healthKitEnabled && healthDataLoaded {
                    HomeHealthGlanceSection(
                        healthDataLoaded: healthDataLoaded,
                        animateRings: animateRings,
                        todaySteps: todaySteps,
                        sleepMinutes: sleepMinutes,
                        restingHR: restingHR,
                        hrv: hrv,
                        activeCalories: activeCalories,
                        todayWaterMl: todayWaterMl,
                        waterProgress: waterProgress,
                        caffeineMg: totalCaffeineMg(at: .now),
                        caffeineLimitMg: Double(settings.dailyCaffeineLimit),
                        creatineTakenToday: creatineTakenToday
                    )
                }
                HomeRecentWorkoutsSection(
                    workouts: allWorkouts,
                    onStartFirstWorkout: { showingAddWorkout = true }
                )
                HomeQuickLinksSection(inProgressWorkout: inProgressWorkout)
            }
        )
    }

    // MARK: - Adaptive Plan Card

    private var adaptivePlanCard: some View {
        AdaptivePlanCardView(
            plan: todayPlan,
            onStart: { showingAddWorkout = true },
            onTapDetail: { showingPlanDetail = true }
        )
    }

    // MARK: - HealthKit Loading

    private func loadHealthData() async {
        let hk = HealthDataCache.shared; let today = Date.now
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

    // MARK: - Quick start (long-press +)

    /// Create a workout immediately using today's smart defaults, bypassing
    /// the AddWorkoutSheet entirely. Used by long-press on the + button so
    /// power users can start a session in one gesture.
    /// - If today's plan name matches a saved template, copies its exercises.
    /// - Otherwise creates an empty workout named after today's plan, or a
    ///   default date-stamped name when nothing is scheduled.
    private func quickStartWorkout() {
        // Prefer the adaptive recommendation. Falls back to the static
        // weekly schedule when no plan has been computed yet (cold cache)
        // or the engine returned "Rest day" — in which case the user
        // long-pressed past the rest suggestion and we honour their
        // schedule rather than naming the workout "Rest day".
        let adaptive: String? = {
            guard todayPlan.intensity != .rest,
                  !todayPlan.recommendedName.isEmpty,
                  todayPlan.recommendedName != "—" else { return nil }
            return todayPlan.recommendedName
        }()
        let weekday = Calendar.current.component(.weekday, from: .now)
        let planName = adaptive ?? settings.weeklyPlan[weekday] ?? ""
        let name = planName.isEmpty
            ? "Workout - \(Date.now.formatted(.dateTime.month(.abbreviated).day()))"
            : planName

        let workout = Workout(name: name, date: .now)
        modelContext.insert(workout)

        // Match by case-insensitive name; copy exercises if found
        if !planName.isEmpty,
           let template = templates.first(where: {
               $0.name.localizedCaseInsensitiveCompare(planName) == .orderedSame
           }) {
            workout.copyExercises(from: template.exercises, into: modelContext)
        }

        modelContext.saveOrLog()
        HapticsManager.workoutStarted()
    }

    // MARK: - Repeat Last Workout

    private func repeatLastWorkout() {
        guard let last = allWorkouts.first else { return }
        let baseName = last.name.components(separatedBy: " - ").first ?? last.name
        let newName = "\(baseName) - \(Date.now.formatted(.dateTime.month(.abbreviated).day()))"
        let workout = Workout(name: newName, date: .now)
        modelContext.insert(workout)
        workout.copyExercises(from: last.exercises, into: modelContext)
        modelContext.saveOrLog()
    }
}

#Preview {
    NavigationStack { HomeDashboardView() }
        .modelContainer(for: Workout.self, inMemory: true)
}
