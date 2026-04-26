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
    @Environment(\.weightUnit) private var weightUnit

    // MARK: - HealthKit State
    @State private var todaySteps: Double = 0
    @State private var restingHR: Double?
    @State private var sleepMinutes: Double = 0
    @State private var hrv: Double?
    @State private var averageHRV: Double?
    @State private var activeCalories: Double = 0
    @State private var averageRestingHR: Double?
    @State private var healthDataLoaded = false
    @State private var externalWorkouts: [ExternalWorkout] = []

    // MARK: - Caffeine Helpers

    private var caffeineHalfLife: Double {
        settings.caffeineHalfLife
    }

    private func totalCaffeineMg(at time: Date) -> Double {
        let hl = caffeineHalfLife
        return caffeineEntries.reduce(0) { $0 + $1.remainingCaffeine(at: time, halfLifeHours: hl) }
    }

    /// Time when caffeine drops below 25mg (sleep-ready threshold)
    private func caffeineClearTime(from now: Date) -> Date? {
        let remaining = totalCaffeineMg(at: now)
        guard remaining >= 25 else { return nil }
        // Binary search for when it drops below 25mg, up to 24 hours out
        var lo: TimeInterval = 0
        var hi: TimeInterval = 24 * 3600
        for _ in 0..<30 {
            let mid = (lo + hi) / 2
            let mgAtMid = totalCaffeineMg(at: now.addingTimeInterval(mid))
            if mgAtMid > 25 {
                lo = mid
            } else {
                hi = mid
            }
        }
        return now.addingTimeInterval(hi)
    }

    /// Suggested bedtime: 10 PM unless caffeine pushes it later
    private func suggestedBedtime(from now: Date) -> (time: Date, delayedByCaffeine: Bool) {
        let calendar = Calendar.current
        var defaultBedtime = calendar.startOfDay(for: now)
        defaultBedtime = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: defaultBedtime)!
        if defaultBedtime < now {
            defaultBedtime = calendar.date(byAdding: .day, value: 1, to: defaultBedtime)!
        }
        if let clearTime = caffeineClearTime(from: now), clearTime > defaultBedtime {
            return (clearTime, true)
        }
        return (defaultBedtime, false)
    }

    // MARK: - Water Helpers

    private var waterGoalMl: Double {
        Double(settings.dailyWaterGoalMl)
    }

    private var todayWaterMl: Double {
        let start = Calendar.current.startOfDay(for: .now)
        return waterEntries.filter { $0.date >= start }.reduce(0) { $0 + $1.milliliters }
    }

    private var waterProgress: Double {
        waterGoalMl > 0 ? min(1.0, todayWaterMl / waterGoalMl) : 0
    }

    // MARK: - Creatine Helpers

    private var creatineTakenToday: Bool {
        let start = Calendar.current.startOfDay(for: .now)
        return creatineEntries.contains { $0.date >= start }
    }

    // MARK: - Animation State
    @State private var animateRings = false

    // MARK: - Sheet State
    @State private var showingAddWorkout = false
    @State private var repeatConfirmation = false

    // MARK: - Computed Helpers

    private var settings: UserSettings {
        settingsArray.first ?? UserSettings()
    }

    private var healthKitEnabled: Bool {
        settingsArray.first?.healthKitEnabled ?? false
    }

    private var workoutsThisWeek: Int {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return 0 }
        return allWorkouts.filter { $0.date >= weekStart }.count
    }

    private var currentStreak: Int {
        Workout.currentStreak(from: allWorkouts)
    }

    // MARK: - Greeting

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let name = settings.userName.isEmpty ? nil : settings.userName
        let timeGreeting: String
        switch hour {
        case 5..<12: timeGreeting = "Good morning"
        case 12..<17: timeGreeting = "Good afternoon"
        case 17..<22: timeGreeting = "Good evening"
        default: timeGreeting = "Good evening"
        }
        if let name { return "\(timeGreeting), \(name)" }
        return timeGreeting
    }

    // MARK: - Recovery Engine

    private var recoveryResult: RecoveryResult {
        RecoveryEngine.evaluate(
            workouts: finishedWorkouts,
            health: HealthSignals(
                todayHRV: hrv,
                averageHRV: averageHRV,
                todayRestingHR: restingHR,
                averageRestingHR: averageRestingHR,
                sleepMinutes: healthDataLoaded ? sleepMinutes : nil
            ),
            externalWorkouts: externalWorkouts
        )
    }

    // MARK: - Average Workout Rating (last 7 days)

    private var averageRating: Double? {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .distantPast
        let rated = allWorkouts.filter { $0.date >= weekAgo && ($0.rating ?? 0) > 0 }
        guard !rated.isEmpty else { return nil }
        return Double(rated.compactMap(\.rating).reduce(0, +)) / Double(rated.count)
    }

    // MARK: - Today's Workout

    private var todaysWorkouts: [Workout] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: .now)
        return allWorkouts.filter { $0.date >= todayStart }
    }

    private var todayTotalSets: Int {
        todaysWorkouts.reduce(0) { total, workout in
            total + workout.exercises.reduce(0) { $0 + $1.sets.filter { !$0.isWarmUp }.count }
        }
    }

    private var todayTotalVolumeKg: Double {
        todaysWorkouts.reduce(0.0) { total, workout in
            total + workout.exercises.reduce(0.0) { exTotal, exercise in
                exTotal + exercise.sets.filter { !$0.isWarmUp }.reduce(0.0) { $0 + Double($1.reps) * $1.weight }
            }
        }
    }

    private var todayMuscleGroups: [MuscleGroup] {
        let groups = Set(todaysWorkouts.flatMap { $0.exercises.compactMap(\.category) })
        return Array(groups).sorted { $0.rawValue < $1.rawValue }
    }

    // MARK: - In-Progress Workout

    private var inProgressWorkout: Workout? {
        allWorkouts.first { !$0.isFinished }
    }

    // MARK: - Progression Suggestions

    private struct ProgressionSuggestion: Identifiable {
        let id = UUID()
        let exerciseName: String
        let recommendation: ProgressionRecommendation
    }

    private var progressionSuggestions: [ProgressionSuggestion] {
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .distantPast
        let recentWorkouts = allWorkouts.filter { $0.endTime != nil && $0.date >= twoWeeksAgo }

        var seen = Set<String>()
        var exerciseNames: [String] = []
        for workout in recentWorkouts {
            for exercise in workout.exercises {
                let key = exercise.name.lowercased()
                if !seen.contains(key) {
                    seen.insert(key)
                    exerciseNames.append(exercise.name)
                }
            }
        }

        var suggestions: [ProgressionSuggestion] = []
        let allExercisesFlat = allWorkouts.flatMap(\.exercises)

        for name in exerciseNames {
            let history = allExercisesFlat
                .filter { $0.name.lowercased() == name.lowercased()
                    && !(($0.workout?.isTemplate) ?? true)
                    && !$0.sets.isEmpty }
                .sorted { ($0.workout?.date ?? .distantPast) > ($1.workout?.date ?? .distantPast) }

            let sessions = ProgressionAdvisor.buildSessions(from: history)
            guard sessions.count >= 2 else { continue }
            let category = history.first?.category
            let rec = ProgressionAdvisor.recommend(sessions: sessions, muscleGroup: category)

            if case .increase = rec.action {
                suggestions.append(ProgressionSuggestion(exerciseName: name, recommendation: rec))
            }
        }

        return Array(suggestions.sorted { $0.recommendation.confidence > $1.recommendation.confidence }.prefix(3))
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                if healthKitEnabled && healthDataLoaded {
                    healthGlanceSection
                }

                if !caffeineEntries.isEmpty && totalCaffeineMg(at: .now) >= 25 {
                    bedtimeSuggestionSection
                }

                if !todaysWorkouts.isEmpty {
                    todayWorkoutSection
                }

                trainingStatusSection

                if !progressionSuggestions.isEmpty {
                    progressionSection
                }

                recentWorkoutsSection

                quickLinksSection
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(greeting)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    if let lastWorkout = allWorkouts.first, !lastWorkout.exercises.isEmpty {
                        Button {
                            repeatConfirmation = true
                        } label: {
                            Label("Repeat Last", systemImage: "arrow.counterclockwise")
                        }
                    }
                    Button {
                        showingAddWorkout = true
                    } label: {
                        Label("Add Workout", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddWorkout) {
            AddWorkoutSheet()
                .environment(\.weightUnit, weightUnit)
        }
        .confirmationDialog("Repeat your last workout?", isPresented: $repeatConfirmation) {
            Button("Repeat \"\(allWorkouts.first?.name ?? "")\"") {
                repeatLastWorkout()
            }
        } message: {
            Text("This will create a new workout with the same exercises (no sets copied).")
        }
        .task {
            guard healthKitEnabled else { return }
            await loadHealthData()
            withAnimation(.easeOut(duration: 0.8)) {
                animateRings = true
            }
        }
        .refreshable {
            if healthKitEnabled {
                animateRings = false
                await loadHealthData()
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                withAnimation(.easeOut(duration: 0.8)) {
                    animateRings = true
                }
            }
        }
    }

    // MARK: - Section 1: Health At A Glance

    private var healthGlanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Health")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                NavigationLink { StepsDetailView() } label: {
                    compactHealthCard(
                        icon: "figure.walk", color: .green,
                        value: HealthFormatters.formatSteps(todaySteps), label: "Steps",
                        progress: todaySteps / 10_000
                    )
                }
                .buttonStyle(.plain)

                NavigationLink { SleepDetailView() } label: {
                    compactHealthCard(
                        icon: "bed.double.fill", color: .indigo,
                        value: HealthFormatters.formatSleepShort(sleepMinutes), label: "Sleep",
                        progress: sleepMinutes / 480
                    )
                }
                .buttonStyle(.plain)

                NavigationLink { HeartRateDetailView() } label: {
                    compactHealthCard(
                        icon: "heart.fill", color: .red,
                        value: restingHR.map { "\(Int($0))" } ?? "—", label: "Resting HR",
                        progress: nil
                    )
                }
                .buttonStyle(.plain)

                NavigationLink { HealthDashboardView() } label: {
                    compactHealthCard(
                        icon: "waveform.path.ecg", color: .purple,
                        value: hrv.map { "\(Int($0)) ms" } ?? "—", label: "HRV",
                        progress: nil
                    )
                }
                .buttonStyle(.plain)

                NavigationLink { HealthDashboardView() } label: {
                    compactHealthCard(
                        icon: "flame.fill", color: .orange,
                        value: "\(Int(activeCalories))", label: "Active Cal",
                        progress: nil
                    )
                }
                .buttonStyle(.plain)

                NavigationLink { WaterTrackerView() } label: {
                    compactHealthCard(
                        icon: "drop.fill", color: .cyan,
                        value: "\(Int(todayWaterMl)) ml", label: "Water",
                        progress: waterProgress
                    )
                }
                .buttonStyle(.plain)

                if !caffeineEntries.isEmpty {
                    let caffeineMg = totalCaffeineMg(at: .now)
                    if caffeineMg > 0.5 {
                        NavigationLink { CaffeineTrackerView() } label: {
                            compactHealthCard(
                                icon: "cup.and.saucer.fill", color: .brown,
                                value: "\(Int(caffeineMg)) mg", label: "Caffeine",
                                progress: min(1.0, caffeineMg / Double(settings.dailyCaffeineLimit))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                NavigationLink { CreatineTrackerView() } label: {
                    compactHealthCard(
                        icon: "pill.fill", color: .blue,
                        value: creatineTakenToday ? "Taken" : "Not yet", label: "Creatine",
                        progress: creatineTakenToday ? 1.0 : 0
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }

    private func compactHealthCard(icon: String, color: Color, value: String, label: String, progress: Double?) -> some View {
        HStack(spacing: 10) {
            if let progress {
                ZStack {
                    Circle()
                        .stroke(.quaternary, lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: animateRings ? min(1.0, progress) : 0)
                        .stroke(color.gradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.8), value: animateRings)
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(color)
                }
                .frame(width: 32, height: 32)
            } else {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(color)
                }
                .frame(width: 32, height: 32)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .monospacedDigit()
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Bedtime Suggestion

    private var bedtimeSuggestionSection: some View {
        let bedtime = suggestedBedtime(from: .now)
        return NavigationLink { CaffeineTrackerView() } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(bedtime.delayedByCaffeine ? Color.orange.opacity(0.15) : Color.indigo.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: bedtime.delayedByCaffeine ? "moon.fill" : "moon.zzz.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(bedtime.delayedByCaffeine ? .orange : .indigo)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Suggested Bedtime")
                        .font(.subheadline.weight(.semibold))
                    HStack(spacing: 4) {
                        Text(bedtime.time, format: .dateTime.hour().minute())
                            .font(.caption.weight(.medium))
                        if bedtime.delayedByCaffeine {
                            Text("Caffeine still active")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                Spacer()
                if let clearTime = caffeineClearTime(from: .now) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Clear by")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(clearTime, format: .dateTime.hour().minute())
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.brown)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section 2: Training Status

    private var trainingStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Training")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                if settings.weeklyGoal > 0 {
                    HStack {
                        Image(systemName: "target")
                            .foregroundStyle(Color.accentColor)
                        Text("\(workoutsThisWeek)/\(settings.weeklyGoal) workouts this week")
                            .font(.subheadline)
                        Spacer()
                        if workoutsThisWeek >= settings.weeklyGoal {
                            Text("Done!")
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                        }
                    }
                    ProgressView(value: Double(workoutsThisWeek), total: Double(settings.weeklyGoal))
                        .tint(workoutsThisWeek >= settings.weeklyGoal ? .green : .accentColor)
                }

                if healthKitEnabled && healthDataLoaded {
                    Divider()

                    HStack(spacing: 12) {
                        Image(systemName: "battery.100.bolt")
                            .foregroundStyle(RecoveryEngine.readinessColor(recoveryResult.readinessScore))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Recovery Readiness")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 6) {
                                ProgressView(value: recoveryResult.readinessScore)
                                    .tint(RecoveryEngine.readinessColor(recoveryResult.readinessScore))
                                    .frame(maxWidth: 120)
                                Text("\(Int(recoveryResult.readinessScore * 100))%")
                                    .font(.subheadline.weight(.bold).monospacedDigit())
                                    .foregroundStyle(RecoveryEngine.readinessColor(recoveryResult.readinessScore))
                            }
                        }
                        Spacer()
                    }
                }

                if let avgRating = averageRating {
                    Divider()

                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text(String(format: "%.1f", avgRating))
                            .font(.subheadline.weight(.medium))
                        Text("avg rating this week")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(currentStreak >= 3 ? .orange : .secondary)
                        Text("\(currentStreak) day streak")
                            .font(.subheadline.weight(.medium))
                    }

                    Spacer()

                    NavigationLink { SmartSuggestionsView() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "brain.head.profile")
                                .font(.caption)
                            Text(recoveryResult.suggestedWorkoutType)
                                .font(.caption.weight(.medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.purple.opacity(0.12), in: Capsule())
                        .foregroundStyle(.purple)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Today's Workout Summary

    private var todayWorkoutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text("\(todaysWorkouts.count)")
                            .font(.title2.weight(.bold).monospacedDigit())
                        Text(todaysWorkouts.count == 1 ? "Workout" : "Workouts")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    Divider().frame(height: 36)

                    VStack(spacing: 2) {
                        Text("\(todayTotalSets)")
                            .font(.title2.weight(.bold).monospacedDigit())
                        Text("Sets")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    Divider().frame(height: 36)

                    VStack(spacing: 2) {
                        Text(weightUnit.format(todayTotalVolumeKg))
                            .font(.title2.weight(.bold).monospacedDigit())
                        Text("Volume")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                if !todayMuscleGroups.isEmpty {
                    Divider()
                    HStack(spacing: 6) {
                        ForEach(todayMuscleGroups, id: \.self) { group in
                            HStack(spacing: 3) {
                                Image(systemName: group.icon)
                                    .font(.system(size: 9))
                                Text(group.rawValue)
                            }
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.1), in: .capsule)
                            .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Section 3: Ready to Progress

    private var progressionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                Text("Ready to Progress")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(progressionSuggestions.enumerated()), id: \.element.id) { index, suggestion in
                    NavigationLink(value: suggestion.exerciseName) {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.exerciseName)
                                    .font(.subheadline.weight(.semibold))
                                if case .increase(let kg) = suggestion.recommendation.action {
                                    Text("Try \(weightUnit.format(kg)) next session")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal)
                    }
                    .buttonStyle(.plain)

                    if index < progressionSuggestions.count - 1 {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Section 4: Recent Workouts

    private var recentWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Workouts")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if allWorkouts.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "dumbbell.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No workouts yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        showingAddWorkout = true
                    } label: {
                        Text("Start Workout")
                            .font(.subheadline.bold())
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(allWorkouts.prefix(5).enumerated()), id: \.element.id) { index, workout in
                        NavigationLink(value: workout) {
                            HStack {
                                WorkoutCardView(workout: workout)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)

                        if index < min(allWorkouts.count, 5) - 1 {
                            Divider().padding(.leading, 20)
                        }
                    }
                }
                .padding(.horizontal)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))

                if allWorkouts.count > 5 {
                    NavigationLink {
                        FullWorkoutListView()
                    } label: {
                        HStack {
                            Text("See All Workouts")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text("\(allWorkouts.count)")
                                .font(.caption.bold().monospacedDigit())
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Section 5: Quick Links

    private var quickLinksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Access")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                if let active = inProgressWorkout {
                    NavigationLink(value: active) {
                        quickLinkCard(icon: "play.circle.fill", color: .orange, title: "Continue Workout")
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    showingAddWorkout = true
                } label: {
                    quickLinkCard(icon: "plus.circle.fill", color: .accentColor, title: "Start Workout")
                }
                .buttonStyle(.plain)

                NavigationLink { ExerciseLibraryView() } label: {
                    quickLinkCard(icon: "books.vertical", color: .blue, title: "Exercise Library")
                }
                .buttonStyle(.plain)

                NavigationLink { InsightsView() } label: {
                    quickLinkCard(icon: "chart.bar", color: .green, title: "Insights")
                }
                .buttonStyle(.plain)

                if inProgressWorkout == nil {
                    NavigationLink { HealthDashboardView() } label: {
                        quickLinkCard(icon: "heart.text.square", color: .red, title: "Health")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func quickLinkCard(icon: String, color: Color, title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)
            Text(title)
                .font(.subheadline.weight(.medium))
            Spacer()
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - HealthKit Loading

    private func loadHealthData() async {
        let hk = HealthKitManager.shared
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

    // MARK: - Repeat Last Workout

    private func repeatLastWorkout() {
        guard let last = allWorkouts.first else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let newName = "\(last.name.components(separatedBy: " - ").first ?? last.name) - \(formatter.string(from: .now))"
        let workout = Workout(name: newName, date: .now)
        modelContext.insert(workout)
        let sortedExercises = last.exercises.sorted { $0.order < $1.order }
        for (index, oldExercise) in sortedExercises.enumerated() {
            let exercise = Exercise(name: oldExercise.name, workout: workout, category: oldExercise.category)
            exercise.order = index
            exercise.supersetGroup = oldExercise.supersetGroup
            exercise.notes = oldExercise.notes
            exercise.customRestDuration = oldExercise.customRestDuration
            modelContext.insert(exercise)
            workout.exercises.append(exercise)
        }
        try? modelContext.save()
    }

    // MARK: - Formatting

}

#Preview {
    NavigationStack {
        HomeDashboardView()
    }
    .modelContainer(for: Workout.self, inMemory: true)
}
