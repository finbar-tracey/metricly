import SwiftUI
import SwiftData

struct HomeDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Workout> { !$0.isTemplate && $0.endTime != nil }, sort: \Workout.date, order: .reverse)
    private var finishedWorkouts: [Workout]
    @Query(filter: #Predicate<Workout> { !$0.isTemplate }, sort: \Workout.date, order: .reverse)
    private var allWorkouts: [Workout]
    @Query private var settingsArray: [UserSettings]
    @Query(sort: \CaffeineEntry.date, order: .reverse) private var caffeineEntries: [CaffeineEntry]
    @Query(sort: \WaterEntry.date, order: .reverse) private var waterEntries: [WaterEntry]
    @Query(sort: \CreatineEntry.date, order: .reverse) private var creatineEntries: [CreatineEntry]
    @Query(sort: \CardioSession.date, order: .reverse) private var cardioSessions: [CardioSession]
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
    @State private var repeatConfirmation = false
    @State private var tappedDayWorkout: Workout?
    @State private var cachedProgressionSuggestions: [ProgressionSuggestion] = []

    // MARK: - Caffeine Helpers

    private var caffeineHalfLife: Double { settings.caffeineHalfLife }

    private func totalCaffeineMg(at time: Date) -> Double {
        let hl = caffeineHalfLife
        return caffeineEntries.reduce(0) { $0 + $1.remainingCaffeine(at: time, halfLifeHours: hl) }
    }

    private func caffeineClearTime(from now: Date) -> Date? {
        let remaining = totalCaffeineMg(at: now)
        guard remaining >= 25 else { return nil }
        var lo: TimeInterval = 0; var hi: TimeInterval = 24 * 3600
        for _ in 0..<30 {
            let mid = (lo + hi) / 2
            if totalCaffeineMg(at: now.addingTimeInterval(mid)) > 25 { lo = mid } else { hi = mid }
        }
        return now.addingTimeInterval(hi)
    }

    private func suggestedBedtime(from now: Date) -> (time: Date, delayedByCaffeine: Bool) {
        let calendar = Calendar.current
        var defaultBedtime = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: calendar.startOfDay(for: now))
            ?? now.addingTimeInterval(3600 * 4)
        if defaultBedtime < now {
            defaultBedtime = calendar.date(byAdding: .day, value: 1, to: defaultBedtime) ?? defaultBedtime
        }
        if let clearTime = caffeineClearTime(from: now), clearTime > defaultBedtime { return (clearTime, true) }
        return (defaultBedtime, false)
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
            cardioSessions: Array(cardioSessions.prefix(50))
        )
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .distantPast
        let recent = finishedWorkouts.filter { $0.date >= twoWeeksAgo }
        let plan = TodayPlanEngine.generate(
            scheduledName: settings.weeklyPlan[todayWeekday],
            recovery: recovery,
            health: liveHealthSignals,
            recentWorkouts: recent,
            alreadyTrainedToday: !todaysWorkouts.filter(\.isFinished).isEmpty
                || cardioSessions.contains { Calendar.current.isDateInToday($0.date) }
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

    // MARK: - Hero Section

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

    private var topSection: AnyView {
        AnyView(
            VStack(spacing: AppTheme.sectionSpacing) {
                heroSection
                if let cta = contextualCTA {
                    switch cta {
                    case .continueWorkout, .greatSession:
                        contextualCTACard(cta)
                    default:
                        EmptyView()
                    }
                }
                adaptivePlanCard
                planAndMetricsRow
            }
        )
    }

    private var middleSection: AnyView {
        AnyView(
            VStack(spacing: AppTheme.sectionSpacing) {
                if healthKitEnabled && healthDataLoaded {
                    muscleReadinessCard
                }
                if !caffeineEntries.isEmpty && totalCaffeineMg(at: .now) >= 25 {
                    bedtimeSuggestionCard
                }
                trainingStatusCard
                if !cardioSessions.isEmpty {
                    cardioCard
                }
            }
        )
    }

    private var bottomSection: AnyView {
        AnyView(
            VStack(spacing: AppTheme.sectionSpacing) {
                if !cachedProgressionSuggestions.isEmpty {
                    progressionCard
                }
                if healthKitEnabled && healthDataLoaded {
                    healthGlanceCard
                }
                recentWorkoutsCard
                quickLinksCard
            }
        )
    }

    private var heroSection: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: heroGradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .animation(.easeInOut(duration: 0.6), value: healthDataLoaded)
            // Top sheen for depth
            LinearGradient(
                colors: [.white.opacity(0.18), .clear],
                startPoint: .top, endPoint: .center
            )
            .blendMode(.plusLighter)
            Circle().fill(.white.opacity(0.10)).frame(width: 220).blur(radius: 12).offset(x: 180, y: -70)
            Circle().fill(.white.opacity(0.06)).frame(width: 140).blur(radius: 10).offset(x: 260, y: 60)

            VStack(alignment: .leading, spacing: 16) {
                // Greeting
                Text(greeting)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)

                if healthKitEnabled && healthDataLoaded {
                    // Score + HRV ring side by side
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Recovery Readiness")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.78))
                                .tracking(0.5)
                                .textCase(.uppercase)
                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                AnimatedInt(
                                    value: Int(recoveryResult.readinessScore * 100),
                                    font: .system(size: 68, weight: .black, design: .rounded),
                                    color: .white
                                )
                                .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
                                Text("%")
                                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.78))
                                    .padding(.bottom, 6)
                            }
                            Text(readinessShortLabel)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(readinessTintColor)
                            Text(RecoveryEngine.readinessLabel(recoveryResult.readinessScore))
                                .font(.caption).foregroundStyle(.white.opacity(0.65))
                                .fixedSize(horizontal: false, vertical: true)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 8)
                        if let hrvValue = hrv {
                            hervRing(value: hrvValue)
                        }
                    }

                    // Suggestion chip — train or rest depending on readiness
                    let score = recoveryResult.readinessScore
                    if score >= 0.50 {
                        Button { showingAddWorkout = true } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("Great day to train \(recoveryResult.suggestedWorkoutType)")
                                    .font(.caption.weight(.semibold))
                                Spacer(minLength: 4)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(.ultraThinMaterial.opacity(0.65), in: RoundedRectangle(cornerRadius: AppTheme.chipRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.chipRadius)
                                    .stroke(.white.opacity(0.22), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.pressableCard)
                    } else if score < 0.40 {
                        NavigationLink { MuscleRecoveryView() } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "moon.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("Rest day recommended")
                                    .font(.caption.weight(.semibold))
                                Spacer(minLength: 4)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(.ultraThinMaterial.opacity(0.65), in: RoundedRectangle(cornerRadius: AppTheme.chipRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.chipRadius)
                                    .stroke(.white.opacity(0.22), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.pressableCard)
                    }
                } else {
                    // No health data — show streak
                    Text("Day Streak")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))
                        .tracking(0.5)
                        .textCase(.uppercase)
                    HStack(alignment: .lastTextBaseline, spacing: 12) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundStyle(.white.opacity(0.92))
                            .shadow(color: .black.opacity(0.20), radius: 6, x: 0, y: 3)
                        AnimatedInt(
                            value: currentStreak,
                            font: .system(size: 76, weight: .black, design: .rounded),
                            color: .white
                        )
                        .shadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 5)
                    }
                }

                weekActivityStrip
            }
            .padding(20)
        }
        .heroCard()
    }

    // MARK: - Readiness helpers

    private var readinessShortLabel: String {
        let s = recoveryResult.readinessScore
        if s >= 0.80 { return "Fully recovered" }
        if s >= 0.60 { return "Mostly recovered" }
        if s >= 0.40 { return "Partially recovered" }
        return "Low readiness"
    }

    private var readinessTintColor: Color {
        let s = recoveryResult.readinessScore
        if s >= 0.60 { return Color(red: 0.25, green: 0.95, blue: 0.55) }
        if s >= 0.40 { return .yellow }
        return .orange
    }

    private func hervRing(value: Double) -> some View {
        let progress = CGFloat(min(value / 100.0, 1.0))
        return ZStack {
            // Background track
            Circle()
                .stroke(.white.opacity(0.22), lineWidth: 8)
                .frame(width: 96, height: 96)
            // Filled arc
            Circle()
                .trim(from: 0, to: animateRings ? progress : 0)
                .stroke(readinessTintColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 96, height: 96)
                .animation(.easeOut(duration: 1.0), value: animateRings)
            // Inner content
            VStack(spacing: 3) {
                ZStack {
                    Circle()
                        .fill(readinessTintColor.opacity(0.20))
                        .frame(width: 32, height: 32)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(readinessTintColor)
                }
                Text("HRV")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.60))
                Text("\(Int(value)) ms")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Week Activity Strip

    private var currentWeekDays: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let weekday = calendar.component(.weekday, from: today) // 1=Sun, 2=Mon…
        let daysFromMonday = (weekday + 5) % 7
        guard let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    private var weekActivityStrip: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let days = currentWeekDays
        let labels = ["M", "T", "W", "T", "F", "S", "S"]
        let accentBase = heroGradientColors.first ?? .accentColor

        return HStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.offset) { i, day in
                let isToday = calendar.isDate(day, inSameDayAs: today)
                let isFuture = day > today
                let hasWorkout = allWorkouts.contains { calendar.isDate($0.date, inSameDayAs: day) }

                let workout = allWorkouts.first { calendar.isDate($0.date, inSameDayAs: day) }
                Button {
                    if let workout { tappedDayWorkout = workout }
                } label: {
                    VStack(spacing: 5) {
                        Text(labels[i])
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(isToday ? 1.0 : 0.55))

                        ZStack {
                            Circle()
                                .fill(hasWorkout ? .white : .white.opacity(isFuture ? 0.08 : 0.15))
                                .frame(width: 28, height: 28)

                            if isToday && !hasWorkout {
                                Circle()
                                    .stroke(.white.opacity(0.7), lineWidth: 1.5)
                                    .frame(width: 28, height: 28)
                            }

                            if hasWorkout {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(accentBase)
                            } else if isToday {
                                Circle()
                                    .fill(.white.opacity(0.6))
                                    .frame(width: 6, height: 6)
                            }
                        }
                    }
                }
                .buttonStyle(.pressableCard)
                .disabled(workout == nil)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Contextual CTA

    private enum CTAType {
        case readyToTrain(String)
        case continueWorkout(Workout)
        case restDay
        case greatSession
    }

    private var contextualCTA: CTAType? {
        if let active = inProgressWorkout { return .continueWorkout(active) }
        if !todaysWorkouts.isEmpty && todaysWorkouts.allSatisfy(\.isFinished) { return .greatSession }
        if healthKitEnabled && healthDataLoaded {
            let score = recoveryResult.readinessScore
            if score >= 0.70 { return .readyToTrain(recoveryResult.suggestedWorkoutType) }
            if score < 0.40 { return .restDay }
        } else if todaysWorkouts.isEmpty {
            return .readyToTrain(recoveryResult.suggestedWorkoutType)
        }
        return nil
    }

    @ViewBuilder
    private func contextualCTACard(_ cta: CTAType) -> some View {
        switch cta {
        case .readyToTrain(let type):
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.green.opacity(0.12)).frame(width: 50, height: 50)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 22, weight: .semibold)).foregroundStyle(.green)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Great day to train")
                        .font(.subheadline.weight(.semibold))
                    Text("\(type) recommended")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { showingAddWorkout = true } label: {
                    Text("Start")
                        .font(.subheadline.bold()).foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(
                            LinearGradient(
                                colors: [.green, Color(red: 0.10, green: 0.72, blue: 0.40)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            in: Capsule()
                        )
                        .shadow(color: .green.opacity(0.45), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.pressableCard)
            }
            .appCard()

        case .continueWorkout(let workout):
            NavigationLink(value: workout) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(Color.orange.opacity(0.16)).frame(width: 50, height: 50)
                        Image(systemName: "play.fill")
                            .font(.system(size: 20, weight: .semibold)).foregroundStyle(.orange)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Workout in progress")
                            .font(.subheadline.weight(.semibold))
                        Text(workout.name).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("Continue")
                        .font(.subheadline.bold()).foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(
                            LinearGradient(
                                colors: [.orange, Color(red: 0.95, green: 0.45, blue: 0.20)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            in: Capsule()
                        )
                        .shadow(color: .orange.opacity(0.45), radius: 8, x: 0, y: 4)
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                }
                .appCard()
            }
            .buttonStyle(.pressableCard)

        case .restDay:
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.indigo.opacity(0.12)).frame(width: 50, height: 50)
                    Image(systemName: "moon.fill")
                        .font(.system(size: 20, weight: .semibold)).foregroundStyle(.indigo)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Rest day recommended")
                        .font(.subheadline.weight(.semibold))
                    Text("Your body is still recovering")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                NavigationLink { MuscleRecoveryView() } label: {
                    Text("Details")
                        .font(.caption.bold()).foregroundStyle(.indigo)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.indigo.opacity(0.1), in: Capsule())
                }
                .buttonStyle(.pressableCard)
            }
            .appCard()

        case .greatSession:
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.yellow.opacity(0.12)).frame(width: 50, height: 50)
                    Image(systemName: "star.fill")
                        .font(.system(size: 20, weight: .semibold)).foregroundStyle(.yellow)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Nice work today!")
                        .font(.subheadline.weight(.semibold))
                    let sets = todayTotalSets
                    Text("\(sets) set\(sets == 1 ? "" : "s") logged · \(weightUnit.formatShort(todayTotalVolumeKg)) volume")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .appCard()
        }
    }

    // MARK: - Adaptive Plan Card

    private var adaptivePlanCard: some View {
        AdaptivePlanCardView(
            plan: todayPlan,
            onStart: { showingAddWorkout = true },
            onTapDetail: { showingPlanDetail = true }
        )
    }

    // MARK: - Plan + Metrics Row

    private var planAndMetricsRow: some View {
        HStack(alignment: .top, spacing: 12) {
            todayPlanMiniCard
            keyMetricsMiniCard
        }
    }

    private var todayPlanMiniCard: some View {
        let planned = settings.weeklyPlan[todayWeekday]
        let doneCount = todaysWorkouts.filter(\.isFinished).count
        let totalCount = max(1, todaysWorkouts.count)
        let progress = Double(doneCount) / Double(totalCount)
        let hasPlan = planned?.isEmpty == false

        return VStack(alignment: .leading, spacing: 10) {
            Text("Today's Plan")
                .font(.system(size: 16, weight: .bold, design: .rounded))

            if hasPlan, let name = planned {
                HStack(spacing: 4) {
                    Text("\(doneCount)/\(totalCount) completed")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(doneCount >= totalCount ? Color.green : Color.accentColor)
                    Spacer()
                }
                GradientProgressBar(value: progress, color: doneCount >= totalCount ? .green : .accentColor, height: 5)
                    .padding(.bottom, 2)

                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(doneCount > 0 ? Color.green.opacity(0.15) : Color(.tertiarySystemGroupedBackground))
                            .frame(width: 30, height: 30)
                        Image(systemName: doneCount > 0 ? "checkmark" : "dumbbell.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(doneCount > 0 ? Color.green : Color.accentColor)
                    }
                    Text(name)
                        .font(.caption.weight(.semibold))
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(todaysWorkouts.isEmpty ? "No workout scheduled" : "\(todaysWorkouts.count) workout\(todaysWorkouts.count == 1 ? "" : "s") today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !todaysWorkouts.isEmpty {
                        Text("\(todayTotalSets) sets · \(weightUnit.formatShort(todayTotalVolumeKg))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            Button { showingAddWorkout = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Start Workout")
                        .font(.caption.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(.white)
                .padding(.vertical, 11)
                .background(
                    LinearGradient(
                        colors: [.green, Color(red: 0.10, green: 0.72, blue: 0.40)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 11)
                )
                .shadow(color: .green.opacity(0.40), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.pressableCard)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: 5)
    }

    private var keyMetricsMiniCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Key Metrics")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Spacer()
                NavigationLink { HealthDashboardView() } label: {
                    Text("View all")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }

            if healthKitEnabled && healthDataLoaded {
                VStack(spacing: 0) {
                    miniMetricRow(icon: "moon.zzz.fill", color: .indigo, label: "Sleep",
                                  value: HealthFormatters.formatSleepShort(sleepMinutes),
                                  status: sleepMinutes >= 420 ? "Good" : "Fair",
                                  good: sleepMinutes >= 420)
                    Divider().padding(.vertical, 5)
                    miniMetricRow(icon: "heart.fill", color: .red, label: "Resting HR",
                                  value: restingHR.map { "\(Int($0)) bpm" } ?? "—",
                                  status: restingHR.map { $0 < 70 ? "Good" : "Fair" } ?? "",
                                  good: restingHR.map { $0 < 70 } ?? false)
                    Divider().padding(.vertical, 5)
                    miniMetricRow(icon: "flame.fill", color: .orange, label: "Calories",
                                  value: "\(Int(activeCalories))",
                                  status: activeCalories >= 300 ? "On track" : "Low",
                                  good: activeCalories >= 300)
                    Divider().padding(.vertical, 5)
                    miniMetricRow(icon: "drop.fill", color: .cyan, label: "Hydration",
                                  value: todayWaterMl >= 1000 ? String(format: "%.1f L", todayWaterMl / 1000) : "\(Int(todayWaterMl)) ml",
                                  status: waterProgress >= 0.7 ? "Good" : "Low",
                                  good: waterProgress >= 0.7)
                }
            } else {
                VStack(spacing: 0) {
                    miniMetricRow(icon: "dumbbell.fill", color: .accentColor, label: "This week",
                                  value: "\(activitiesThisWeek)", status: settings.weeklyGoal > 0 ? "/ \(settings.weeklyGoal) goal" : "workouts",
                                  good: settings.weeklyGoal > 0 ? activitiesThisWeek >= settings.weeklyGoal : true)
                    Divider().padding(.vertical, 5)
                    miniMetricRow(icon: "flame.fill", color: .orange, label: "Streak",
                                  value: "\(currentStreak) day\(currentStreak == 1 ? "" : "s")",
                                  status: currentStreak >= 3 ? "Active" : "",
                                  good: currentStreak >= 3)
                    Divider().padding(.vertical, 5)
                    miniMetricRow(icon: "scalemass.fill", color: .purple, label: "Volume today",
                                  value: weightUnit.formatShort(todayTotalVolumeKg),
                                  status: todayTotalSets > 0 ? "\(todayTotalSets) sets" : "",
                                  good: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: 5)
    }

    private func miniMetricRow(icon: String, color: Color, label: String, value: String, status: String, good: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 18)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if !status.isEmpty {
                    Text(status)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(good ? Color.green : Color.orange)
                }
            }
        }
    }

    // MARK: - Muscle Readiness Card

    private var muscleReadinessCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "Muscle Readiness", icon: "figure.strengthtraining.traditional", color: .purple)
                Spacer()
                NavigationLink { MuscleRecoveryView() } label: {
                    Text("Details")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.purple)
                }
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 6),
                spacing: 14
            ) {
                ForEach(recoveryResult.muscleResults, id: \.group) { result in
                    let color = RecoveryEngine.freshnessColor(result.freshness)
                    VStack(spacing: 7) {
                        ZStack {
                            Circle()
                                .fill(color.opacity(0.14))
                                .frame(width: 52, height: 52)
                            Circle()
                                .stroke(color.opacity(0.18), lineWidth: 4)
                                .frame(width: 52, height: 52)
                            Circle()
                                .trim(from: 0, to: result.freshness)
                                .stroke(
                                    color.gradient,
                                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .frame(width: 52, height: 52)
                                .animation(.easeOut(duration: 0.7), value: result.freshness)
                                .shadow(color: color.opacity(0.4), radius: 4, y: 1)
                            MuscleIconView(group: result.group, color: color)
                                .frame(width: 22, height: 22)
                        }
                        Text(result.group.rawValue)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(color)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            HStack(spacing: 16) {
                legendDot(color: .green, label: "Ready")
                legendDot(color: .yellow, label: "Almost")
                legendDot(color: .orange, label: "Recovering")
                legendDot(color: .red, label: "Fatigued")
                Spacer()
            }
        }
        .appCard()
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: - Health At A Glance Card

    private var healthGlanceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "All Health Metrics", icon: "heart.circle.fill", color: .red)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                NavigationLink { StepsDetailView() } label: {
                    compactHealthTile(icon: "figure.walk", color: .green,
                                      value: HealthFormatters.formatSteps(todaySteps), label: "Steps",
                                      progress: todaySteps / 10_000)
                }.buttonStyle(.pressableCard)

                NavigationLink { SleepDetailView() } label: {
                    compactHealthTile(icon: "bed.double.fill", color: .indigo,
                                      value: HealthFormatters.formatSleepShort(sleepMinutes), label: "Sleep",
                                      progress: sleepMinutes / 480)
                }.buttonStyle(.pressableCard)

                NavigationLink { HeartRateDetailView() } label: {
                    compactHealthTile(icon: "heart.fill", color: .red,
                                      value: restingHR.map { "\(Int($0))" } ?? "—", label: "Resting HR",
                                      progress: nil)
                }.buttonStyle(.pressableCard)

                NavigationLink { HealthDashboardView() } label: {
                    compactHealthTile(icon: "waveform.path.ecg", color: .purple,
                                      value: hrv.map { "\(Int($0)) ms" } ?? "—", label: "HRV",
                                      progress: nil)
                }.buttonStyle(.pressableCard)

                NavigationLink { HealthDashboardView() } label: {
                    compactHealthTile(icon: "flame.fill", color: .orange,
                                      value: "\(Int(activeCalories))", label: "Active Cal",
                                      progress: nil)
                }.buttonStyle(.pressableCard)

                NavigationLink { WaterTrackerView() } label: {
                    compactHealthTile(icon: "drop.fill", color: .cyan,
                                      value: "\(Int(todayWaterMl)) ml", label: "Water",
                                      progress: waterProgress)
                }.buttonStyle(.pressableCard)

                let caffeineMg = totalCaffeineMg(at: .now)
                if caffeineMg > 0.5 {
                    NavigationLink { CaffeineTrackerView() } label: {
                        compactHealthTile(icon: "cup.and.saucer.fill", color: .brown,
                                          value: "\(Int(caffeineMg)) mg", label: "Caffeine",
                                          progress: min(1.0, caffeineMg / Double(settings.dailyCaffeineLimit)))
                    }.buttonStyle(.pressableCard)
                }

                NavigationLink { CreatineTrackerView() } label: {
                    compactHealthTile(icon: "pill.fill", color: .blue,
                                      value: creatineTakenToday ? "Taken" : "Not yet", label: "Creatine",
                                      progress: creatineTakenToday ? 1.0 : 0)
                }.buttonStyle(.pressableCard)
            }
        }
        .appCard()
        .redacted(reason: healthKitEnabled && !healthDataLoaded ? .placeholder : [])
        .animation(.easeInOut(duration: 0.3), value: healthDataLoaded)
    }

    private func compactHealthTile(icon: String, color: Color, value: String, label: String, progress: Double?) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ZStack {
                    Circle().fill(color.opacity(0.18))
                    if let progress {
                        Circle()
                            .trim(from: 0, to: animateRings ? min(1.0, progress) : 0)
                            .stroke(color.gradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 0.8), value: animateRings)
                    }
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(color)
                }
                .frame(width: 44, height: 44)
                Spacer()
                if let progress {
                    Text("\(Int(min(1, progress) * 100))%")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(color.opacity(0.12), in: Capsule())
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .tracking(0.3)
                    .textCase(.uppercase)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            LinearGradient(
                colors: [color.opacity(0.10), Color(.tertiarySystemGroupedBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(color.opacity(0.18), lineWidth: 0.5)
        )
    }

    // MARK: - Bedtime Suggestion Card

    private var bedtimeSuggestionCard: some View {
        let bedtime = suggestedBedtime(from: .now)
        let color: Color = bedtime.delayedByCaffeine ? .orange : .indigo

        return NavigationLink { CaffeineTrackerView() } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.72)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .shadow(color: color.opacity(0.45), radius: 9, x: 0, y: 4)
                    Image(systemName: bedtime.delayedByCaffeine ? "moon.fill" : "moon.zzz.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Suggested Bedtime")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    HStack(spacing: 6) {
                        Text(bedtime.time, format: .dateTime.hour().minute())
                            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        if bedtime.delayedByCaffeine {
                            Text("· Caffeine still active").font(.caption).foregroundStyle(.orange)
                        }
                    }
                }
                Spacer()
                if let clearTime = caffeineClearTime(from: .now) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Clear by")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .tracking(0.3)
                            .textCase(.uppercase)
                        Text(clearTime, format: .dateTime.hour().minute())
                            .font(.caption.bold().monospacedDigit()).foregroundStyle(.brown)
                    }
                }
                Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.10), radius: 16, x: 0, y: 5)
        }
        .buttonStyle(.pressableCard)
    }

    // MARK: - Training Status Card

    private var trainingStatusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Training", icon: "dumbbell.fill", color: .accentColor)

            VStack(spacing: 0) {
                if settings.weeklyGoal > 0 {
                    let weekProgress = min(1.0, Double(activitiesThisWeek) / Double(settings.weeklyGoal))
                    let weekDone = activitiesThisWeek >= settings.weeklyGoal
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "target").foregroundStyle(weekDone ? Color.green : Color.accentColor)
                                Text("\(activitiesThisWeek)/\(settings.weeklyGoal) workouts this week").font(.subheadline)
                            }
                            Spacer()
                            if weekDone {
                                Text("DONE")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .tracking(0.6)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 9).padding(.vertical, 4)
                                    .background(
                                        LinearGradient(
                                            colors: [.green, Color(red: 0.10, green: 0.72, blue: 0.40)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        ),
                                        in: Capsule()
                                    )
                                    .shadow(color: .green.opacity(0.4), radius: 5, y: 2)
                            }
                        }
                        GradientProgressBar(value: weekProgress, color: weekDone ? .green : .accentColor, height: 10)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                }

                Divider().padding(.leading, 16)

                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(currentStreak >= 3 ? .orange : .secondary)
                        Text("\(currentStreak) day streak")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    Spacer()
                    NavigationLink { SmartSuggestionsView() } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "brain.head.profile").font(.caption.weight(.semibold))
                            Text(recoveryResult.suggestedWorkoutType).font(.caption.weight(.semibold))
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.18), Color.purple.opacity(0.10)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            in: Capsule()
                        )
                        .overlay(Capsule().stroke(Color.purple.opacity(0.20), lineWidth: 0.5))
                        .foregroundStyle(.purple)
                    }
                    .buttonStyle(.pressableCard)
                }
                .padding(.horizontal, 16).padding(.vertical, 14)

                if let avgRating = averageRating {
                    Divider().padding(.leading, 16)
                    HStack(spacing: 5) {
                        Image(systemName: "star.fill").foregroundStyle(.yellow)
                        Text(String(format: "%.1f", avgRating)).font(.subheadline.weight(.medium))
                        Text("avg rating this week").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
            )
        }
        .appCard()
    }

    // MARK: - Progression Card

    private var progressionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Ready to Progress", icon: "chart.line.uptrend.xyaxis", color: .green)

            VStack(spacing: 0) {
                ForEach(Array(cachedProgressionSuggestions.enumerated()), id: \.element.id) { index, suggestion in
                    NavigationLink(value: suggestion.exerciseName) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [.green, Color(red: 0.10, green: 0.72, blue: 0.40)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 38, height: 38)
                                    .shadow(color: .green.opacity(0.40), radius: 6, y: 3)
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(suggestion.exerciseName)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                if case .increase(let kg) = suggestion.recommendation.action {
                                    Text("Try \(weightUnit.format(kg)) next session")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                    }
                    .buttonStyle(.pressableCard)
                    if index < cachedProgressionSuggestions.count - 1 { Divider().padding(.leading, 66) }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
            )
        }
        .appCard()
    }

    // MARK: - Cardio Card

    private var cardioCard: some View {
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .distantPast
        let thisWeekSessions = cardioSessions.filter { $0.date >= weekStart }
        let thisWeekKm = thisWeekSessions.reduce(0) { $0 + $1.distanceMeters } / 1000
        let lastSession = cardioSessions.first
        let distUnit = weightUnit.distanceUnit
        let useKm = distUnit == .km

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "Cardio", icon: "figure.run", color: .orange)
                Spacer()
                NavigationLink { CardioHubView() } label: {
                    Text("See All").font(.caption.weight(.semibold)).foregroundStyle(.orange)
                }
            }

            HStack(spacing: 12) {
                // This week stat
                VStack(alignment: .leading, spacing: 6) {
                    Text("This Week")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                        .tracking(0.4)
                        .textCase(.uppercase)
                    Text(String(format: "%.1f %@", distUnit.display(thisWeekKm), distUnit.label))
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.orange)
                    Text("\(thisWeekSessions.count) session\(thisWeekSessions.count == 1 ? "" : "s")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    LinearGradient(
                        colors: [Color.orange.opacity(0.18), Color.orange.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.orange.opacity(0.20), lineWidth: 0.5)
                )

                // Last run stat
                if let last = lastSession {
                    NavigationLink(destination: CardioSessionDetailView(session: last)) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Last Run")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(last.type.color)
                                .tracking(0.4)
                                .textCase(.uppercase)
                            Text(last.formattedDistance(useKm: useKm))
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(last.type.color)
                            Text(last.formattedPace(useKm: useKm))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(
                            LinearGradient(
                                colors: [last.type.color.opacity(0.18), last.type.color.opacity(0.06)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(last.type.color.opacity(0.20), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.pressableCard)
                }
            }
        }
        .appCard()
    }

    // MARK: - Recent Workouts Card

    private var recentWorkoutsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Recent Workouts", icon: "clock.fill", color: .blue)

            if allWorkouts.isEmpty {
                VStack(spacing: 16) {
                    ZStack {
                        Circle().fill(Color.accentColor.opacity(0.12)).frame(width: 60, height: 60)
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 24, weight: .semibold)).foregroundStyle(Color.accentColor)
                    }
                    Text("No workouts yet").font(.headline)
                    Button {
                        showingAddWorkout = true
                    } label: {
                        Text("Start Your First Workout")
                            .font(.subheadline.bold()).padding(.horizontal, 24).padding(.vertical, 12)
                            .background(Color.accentColor.gradient).foregroundStyle(.white).clipShape(Capsule())
                    }
                    .buttonStyle(.pressableCard)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 30)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(allWorkouts.prefix(5).enumerated()), id: \.element.id) { index, workout in
                        NavigationLink(value: workout) {
                            HStack {
                                WorkoutCardView(workout: workout)
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 4)
                        }
                        .buttonStyle(.pressableCard)
                        if index < min(allWorkouts.count, 5) - 1 { Divider().padding(.leading, 16) }
                    }
                }
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                if allWorkouts.count > 5 {
                    NavigationLink { FullWorkoutListView() } label: {
                        HStack {
                            Text("See All Workouts").font(.subheadline.weight(.medium))
                            Spacer()
                            Text("\(allWorkouts.count)").font(.caption.bold().monospacedDigit()).foregroundStyle(.secondary)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 13)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.pressableCard)
                }
            }
        }
        .appCard()
    }

    // MARK: - Quick Links Card

    private var quickLinksCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Quick Access", icon: "bolt.circle.fill", color: .yellow)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                if let active = inProgressWorkout {
                    NavigationLink(value: active) {
                        quickLinkTile(icon: "play.circle.fill", color: .orange, title: "Continue Workout")
                    }.buttonStyle(.pressableCard)
                } else {
                    NavigationLink { WorkoutScheduleView() } label: {
                        quickLinkTile(icon: "calendar.badge.checkmark", color: .green, title: "Weekly Schedule")
                    }.buttonStyle(.pressableCard)
                }

                NavigationLink { ExerciseLibraryView() } label: {
                    quickLinkTile(icon: "books.vertical", color: .blue, title: "Exercise Library")
                }.buttonStyle(.pressableCard)

                NavigationLink { InsightsView() } label: {
                    quickLinkTile(icon: "chart.bar.fill", color: .purple, title: "Insights")
                }.buttonStyle(.pressableCard)

                NavigationLink { PersonalRecordsView() } label: {
                    quickLinkTile(icon: "trophy.fill", color: .yellow, title: "Personal Records")
                }.buttonStyle(.pressableCard)

                NavigationLink { HealthDashboardView() } label: {
                    quickLinkTile(icon: "heart.text.square", color: .red, title: "Health")
                }.buttonStyle(.pressableCard)
            }
        }
        .appCard()
    }

    private func quickLinkTile(icon: String, color: Color, title: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.72)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                    .shadow(color: color.opacity(0.45), radius: 10, x: 0, y: 5)
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }

    // MARK: - HealthKit Loading

    private func loadHealthData() async {
        let hk = HealthKitManager.shared; let today = Date.now
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
