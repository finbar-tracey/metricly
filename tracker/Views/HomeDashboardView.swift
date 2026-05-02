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

    private var recoveryResult: RecoveryResult {
        RecoveryEngine.evaluate(
            workouts: finishedWorkouts,
            health: HealthSignals(
                todayHRV: hrv, averageHRV: averageHRV,
                todayRestingHR: restingHR, averageRestingHR: averageRestingHR,
                sleepMinutes: healthDataLoaded ? sleepMinutes : nil
            ),
            externalWorkouts: externalWorkouts,
            cardioSessions: Array(cardioSessions.prefix(50))
        )
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
                heroSection

                // Continue / great-session banner only — readyToTrain is now in the hero chip
                if let cta = contextualCTA {
                    switch cta {
                    case .continueWorkout, .greatSession:
                        contextualCTACard(cta)
                    default:
                        EmptyView()
                    }
                }

                planAndMetricsRow

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

                if !cachedProgressionSuggestions.isEmpty {
                    progressionCard
                }

                if healthKitEnabled && healthDataLoaded {
                    healthGlanceCard
                }

                recentWorkoutsCard
                quickLinksCard
            }
            .padding(.horizontal)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
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
        .confirmationDialog("Repeat your last workout?", isPresented: $repeatConfirmation) {
            Button("Repeat \"\(allWorkouts.first?.name ?? "")\"") { repeatLastWorkout() }
        } message: {
            Text("This will create a new workout with the same exercises (no sets copied).")
        }
        .onAppear { buildProgressionSuggestions() }
        .onChange(of: allWorkouts.count) { buildProgressionSuggestions() }
        .task {
            guard healthKitEnabled else { return }
            await loadHealthData()
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
            return [Color.accentColor, Color.blue]
        }
        let score = recoveryResult.readinessScore
        if score >= 0.70 {
            return [Color(red: 0.12, green: 0.65, blue: 0.40), Color(red: 0.0, green: 0.48, blue: 0.55)]
        } else if score >= 0.45 {
            return [Color.orange, Color(red: 0.85, green: 0.55, blue: 0.10)]
        } else {
            return [Color.red, Color(red: 0.85, green: 0.25, blue: 0.20)]
        }
    }

    private var heroSection: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: heroGradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .animation(.easeInOut(duration: 0.6), value: healthDataLoaded)
            Circle().fill(.white.opacity(0.07)).frame(width: 220).offset(x: 180, y: -70)
            Circle().fill(.white.opacity(0.04)).frame(width: 140).offset(x: 260, y: 60)

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
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white.opacity(0.72))
                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                Text("\(Int(recoveryResult.readinessScore * 100))")
                                    .font(.system(size: 52, weight: .black, design: .rounded))
                                    .foregroundStyle(.white).monospacedDigit()
                                Text("%")
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(.white.opacity(0.70))
                                    .padding(.bottom, 4)
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
                            .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
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
                            .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    // No health data — show streak
                    HStack(alignment: .lastTextBaseline, spacing: 10) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 38, weight: .bold)).foregroundStyle(.white.opacity(0.88))
                        Text("\(currentStreak)")
                            .font(.system(size: 56, weight: .black, design: .rounded))
                            .foregroundStyle(.white).monospacedDigit()
                    }
                    Text("Day Streak")
                        .font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.80))
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
                .buttonStyle(.plain)
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
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color.green, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .appCard()

        case .continueWorkout(let workout):
            NavigationLink(value: workout) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(Color.orange.opacity(0.12)).frame(width: 50, height: 50)
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
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color.orange, in: Capsule())
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                }
                .appCard()
            }
            .buttonStyle(.plain)

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
                .buttonStyle(.plain)
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
                .font(.subheadline.weight(.bold))

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
                .padding(.vertical, 10)
                .background(Color.green, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 3)
    }

    private var keyMetricsMiniCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Key Metrics")
                    .font(.subheadline.weight(.bold))
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
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 3)
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
                spacing: 12
            ) {
                ForEach(recoveryResult.muscleResults, id: \.group) { result in
                    let color = RecoveryEngine.freshnessColor(result.freshness)
                    VStack(spacing: 6) {
                        ZStack {
                            Circle().fill(color.opacity(0.12)).frame(width: 46, height: 46)
                            Circle()
                                .trim(from: 0, to: result.freshness)
                                .stroke(color, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .frame(width: 46, height: 46)
                                .animation(.easeOut(duration: 0.7), value: result.freshness)
                            MuscleIconView(group: result.group, color: color)
                                .frame(width: 20, height: 20)
                        }
                        Text(result.group.rawValue)
                            .font(.system(size: 9, weight: .medium))
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
                }.buttonStyle(.plain)

                NavigationLink { SleepDetailView() } label: {
                    compactHealthTile(icon: "bed.double.fill", color: .indigo,
                                      value: HealthFormatters.formatSleepShort(sleepMinutes), label: "Sleep",
                                      progress: sleepMinutes / 480)
                }.buttonStyle(.plain)

                NavigationLink { HeartRateDetailView() } label: {
                    compactHealthTile(icon: "heart.fill", color: .red,
                                      value: restingHR.map { "\(Int($0))" } ?? "—", label: "Resting HR",
                                      progress: nil)
                }.buttonStyle(.plain)

                NavigationLink { HealthDashboardView() } label: {
                    compactHealthTile(icon: "waveform.path.ecg", color: .purple,
                                      value: hrv.map { "\(Int($0)) ms" } ?? "—", label: "HRV",
                                      progress: nil)
                }.buttonStyle(.plain)

                NavigationLink { HealthDashboardView() } label: {
                    compactHealthTile(icon: "flame.fill", color: .orange,
                                      value: "\(Int(activeCalories))", label: "Active Cal",
                                      progress: nil)
                }.buttonStyle(.plain)

                NavigationLink { WaterTrackerView() } label: {
                    compactHealthTile(icon: "drop.fill", color: .cyan,
                                      value: "\(Int(todayWaterMl)) ml", label: "Water",
                                      progress: waterProgress)
                }.buttonStyle(.plain)

                let caffeineMg = totalCaffeineMg(at: .now)
                if caffeineMg > 0.5 {
                    NavigationLink { CaffeineTrackerView() } label: {
                        compactHealthTile(icon: "cup.and.saucer.fill", color: .brown,
                                          value: "\(Int(caffeineMg)) mg", label: "Caffeine",
                                          progress: min(1.0, caffeineMg / Double(settings.dailyCaffeineLimit)))
                    }.buttonStyle(.plain)
                }

                NavigationLink { CreatineTrackerView() } label: {
                    compactHealthTile(icon: "pill.fill", color: .blue,
                                      value: creatineTakenToday ? "Taken" : "Not yet", label: "Creatine",
                                      progress: creatineTakenToday ? 1.0 : 0)
                }.buttonStyle(.plain)
            }
        }
        .appCard()
        .redacted(reason: healthKitEnabled && !healthDataLoaded ? .placeholder : [])
        .animation(.easeInOut(duration: 0.3), value: healthDataLoaded)
    }

    private func compactHealthTile(icon: String, color: Color, value: String, label: String, progress: Double?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle().fill(color.opacity(0.15))
                    if let progress {
                        Circle()
                            .trim(from: 0, to: animateRings ? min(1.0, progress) : 0)
                            .stroke(color.gradient, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 0.8), value: animateRings)
                    }
                    Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(color)
                }
                .frame(width: 40, height: 40)
                Spacer()
                if let progress {
                    Text("\(Int(min(1, progress) * 100))%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(color.opacity(0.8)).monospacedDigit()
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.75)
                Text(label).font(.caption2.weight(.medium)).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Bedtime Suggestion Card

    private var bedtimeSuggestionCard: some View {
        let bedtime = suggestedBedtime(from: .now)
        let color: Color = bedtime.delayedByCaffeine ? .orange : .indigo

        return NavigationLink { CaffeineTrackerView() } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(color.opacity(0.12)).frame(width: 44, height: 44)
                    Image(systemName: bedtime.delayedByCaffeine ? "moon.fill" : "moon.zzz.fill")
                        .font(.system(size: 18, weight: .semibold)).foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Suggested Bedtime").font(.subheadline.weight(.semibold))
                    HStack(spacing: 6) {
                        Text(bedtime.time, format: .dateTime.hour().minute())
                            .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                        if bedtime.delayedByCaffeine {
                            Text("· Caffeine still active").font(.caption).foregroundStyle(.orange)
                        }
                    }
                }
                Spacer()
                if let clearTime = caffeineClearTime(from: .now) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Clear by").font(.caption2).foregroundStyle(.tertiary)
                        Text(clearTime, format: .dateTime.hour().minute())
                            .font(.caption.bold()).foregroundStyle(.brown)
                    }
                }
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
            .shadow(color: .black.opacity(0.07), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(.plain)
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
                                Text("Done!").font(.caption.bold()).foregroundStyle(.green)
                                    .padding(.horizontal, 8).padding(.vertical, 2)
                                    .background(Color.green.opacity(0.12), in: Capsule())
                            }
                        }
                        GradientProgressBar(value: weekProgress, color: weekDone ? .green : .accentColor, height: 9)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                }

                Divider().padding(.leading, 16)

                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(currentStreak >= 3 ? .orange : .secondary)
                        Text("\(currentStreak) day streak").font(.subheadline.weight(.medium))
                    }
                    Spacer()
                    NavigationLink { SmartSuggestionsView() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "brain.head.profile").font(.caption)
                            Text(recoveryResult.suggestedWorkoutType).font(.caption.weight(.medium))
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.purple.opacity(0.12), in: Capsule())
                        .foregroundStyle(.purple)
                    }
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
            .clipShape(RoundedRectangle(cornerRadius: 14))
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
                                Circle().fill(Color.green.opacity(0.12)).frame(width: 36, height: 36)
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(.green)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.exerciseName).font(.subheadline.weight(.semibold))
                                if case .increase(let kg) = suggestion.recommendation.action {
                                    Text("Try \(weightUnit.format(kg)) next session")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    if index < cachedProgressionSuggestions.count - 1 { Divider().padding(.leading, 66) }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
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
                VStack(alignment: .leading, spacing: 4) {
                    Text("This Week")
                        .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    Text(String(format: "%.1f %@", distUnit.display(thisWeekKm), distUnit.label))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.orange)
                    Text("\(thisWeekSessions.count) session\(thisWeekSessions.count == 1 ? "" : "s")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

                // Last run stat
                if let last = lastSession {
                    NavigationLink(destination: CardioSessionDetailView(session: last)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Last Run")
                                .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                            Text(last.formattedDistance(useKm: useKm))
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(last.type.color)
                            Text(last.formattedPace(useKm: useKm))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(last.type.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
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
                    .buttonStyle(.plain)
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
                        .buttonStyle(.plain)
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
                    .buttonStyle(.plain)
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
                    }.buttonStyle(.plain)
                } else {
                    NavigationLink { WorkoutScheduleView() } label: {
                        quickLinkTile(icon: "calendar.badge.checkmark", color: .green, title: "Weekly Schedule")
                    }.buttonStyle(.plain)
                }

                NavigationLink { ExerciseLibraryView() } label: {
                    quickLinkTile(icon: "books.vertical", color: .blue, title: "Exercise Library")
                }.buttonStyle(.plain)

                NavigationLink { InsightsView() } label: {
                    quickLinkTile(icon: "chart.bar.fill", color: .purple, title: "Insights")
                }.buttonStyle(.plain)

                NavigationLink { PersonalRecordsView() } label: {
                    quickLinkTile(icon: "trophy.fill", color: .yellow, title: "Personal Records")
                }.buttonStyle(.plain)

                NavigationLink { HealthDashboardView() } label: {
                    quickLinkTile(icon: "heart.text.square", color: .red, title: "Health")
                }.buttonStyle(.plain)
            }
        }
        .appCard()
    }

    private func quickLinkTile(icon: String, color: Color, title: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(color.gradient).frame(width: 46, height: 46)
                Image(systemName: icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
            }
            Text(title).font(.subheadline.weight(.semibold)).lineLimit(2).multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
