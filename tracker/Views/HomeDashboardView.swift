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
        var defaultBedtime = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: calendar.startOfDay(for: now))!
        if defaultBedtime < now { defaultBedtime = calendar.date(byAdding: .day, value: 1, to: defaultBedtime)! }
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

    private var workoutsThisWeek: Int {
        guard let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start else { return 0 }
        return allWorkouts.filter { $0.date >= weekStart }.count
    }

    private var currentStreak: Int { Workout.currentStreak(from: allWorkouts) }

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
            externalWorkouts: externalWorkouts
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
        todaysWorkouts.reduce(0.0) { total, workout in
            total + workout.exercises.reduce(0.0) { exTotal, exercise in
                exTotal + exercise.sets.filter { !$0.isWarmUp }.reduce(0.0) { $0 + Double($1.reps) * $1.weight }
            }
        }
    }

    private var todayMuscleGroups: [MuscleGroup] {
        Array(Set(todaysWorkouts.flatMap { $0.exercises.compactMap(\.category) })).sorted { $0.rawValue < $1.rawValue }
    }

    private var inProgressWorkout: Workout? { allWorkouts.first { !$0.isFinished } }

    private struct ProgressionSuggestion: Identifiable {
        let id = UUID()
        let exerciseName: String
        let recommendation: ProgressionRecommendation
    }

    private var progressionSuggestions: [ProgressionSuggestion] {
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .distantPast
        let recentWorkouts = allWorkouts.filter { $0.endTime != nil && $0.date >= twoWeeksAgo }
        var seen = Set<String>(); var exerciseNames: [String] = []
        for workout in recentWorkouts {
            for exercise in workout.exercises {
                let key = exercise.name.lowercased()
                if !seen.contains(key) { seen.insert(key); exerciseNames.append(exercise.name) }
            }
        }
        var suggestions: [ProgressionSuggestion] = []
        let allExercisesFlat = allWorkouts.flatMap(\.exercises)
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
        return Array(suggestions.sorted { $0.recommendation.confidence > $1.recommendation.confidence }.prefix(3))
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                heroSection

                if healthKitEnabled && healthDataLoaded {
                    healthGlanceCard
                }

                if !caffeineEntries.isEmpty && totalCaffeineMg(at: .now) >= 25 {
                    bedtimeSuggestionCard
                }

                if !todaysWorkouts.isEmpty {
                    todayWorkoutCard
                }

                trainingStatusCard

                if !progressionSuggestions.isEmpty {
                    progressionCard
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
        .confirmationDialog("Repeat your last workout?", isPresented: $repeatConfirmation) {
            Button("Repeat \"\(allWorkouts.first?.name ?? "")\"") { repeatLastWorkout() }
        } message: {
            Text("This will create a new workout with the same exercises (no sets copied).")
        }
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

            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(greeting).font(.title3.weight(.semibold)).foregroundStyle(.white)
                    Text(Date.now, format: .dateTime.weekday(.wide).month().day())
                        .font(.subheadline).foregroundStyle(.white.opacity(0.72))
                }

                if healthKitEnabled && healthDataLoaded {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .lastTextBaseline, spacing: 2) {
                            Text("\(Int(recoveryResult.readinessScore * 100))")
                                .font(.system(size: 56, weight: .black, design: .rounded))
                                .foregroundStyle(.white).monospacedDigit()
                            Text("%").font(.title.weight(.bold)).foregroundStyle(.white.opacity(0.70)).padding(.bottom, 6)
                        }
                        Text("Recovery Readiness")
                            .font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.80))
                        Text(RecoveryEngine.readinessLabel(recoveryResult.readinessScore))
                            .font(.caption).foregroundStyle(.white.opacity(0.65))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .lastTextBaseline, spacing: 10) {
                            Image(systemName: "flame.fill").font(.system(size: 38, weight: .bold)).foregroundStyle(.white.opacity(0.88))
                            Text("\(currentStreak)").font(.system(size: 56, weight: .black, design: .rounded))
                                .foregroundStyle(.white).monospacedDigit()
                        }
                        Text("Day Streak").font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.80))
                    }
                }

                HStack(spacing: 8) {
                    heroPill(icon: "flame.fill", text: "\(currentStreak) streak")
                    if settings.weeklyGoal > 0 {
                        heroPill(icon: "dumbbell.fill", text: "\(workoutsThisWeek)/\(settings.weeklyGoal) this week")
                    }
                    if let last = allWorkouts.first {
                        heroPill(icon: "clock", text: last.date.formatted(.relative(presentation: .named)))
                    }
                }
            }
            .padding(20)
        }
        .heroCard()
    }

    private func heroPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10, weight: .semibold))
            Text(text).font(.caption.weight(.semibold)).lineLimit(1)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.white.opacity(0.20), in: Capsule())
        .foregroundStyle(.white)
    }

    // MARK: - Health At A Glance Card

    private var healthGlanceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Health", icon: "heart.circle.fill", color: .red)

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

    // MARK: - Today's Workout Card

    private var todayWorkoutCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Today", icon: "calendar.circle.fill", color: .orange)

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    statCol("\(todaysWorkouts.count)", label: todaysWorkouts.count == 1 ? "Workout" : "Workouts")
                    Rectangle().fill(Color(.separator)).frame(width: 1, height: 32)
                    statCol("\(todayTotalSets)", label: "Sets")
                    Rectangle().fill(Color(.separator)).frame(width: 1, height: 32)
                    statCol(weightUnit.formatShort(todayTotalVolumeKg), label: "Volume")
                }
                .padding(.vertical, 14)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                if !todayMuscleGroups.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(todayMuscleGroups, id: \.self) { group in
                                HStack(spacing: 3) {
                                    Image(systemName: group.icon).font(.system(size: 9))
                                    Text(group.rawValue)
                                }
                                .font(.caption2)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.10), in: Capsule())
                                .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .padding(.top, 10)
                }
            }
        }
        .appCard()
    }

    private func statCol(_ value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.title3.weight(.bold).monospacedDigit()).lineLimit(1).minimumScaleFactor(0.75)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Training Status Card

    private var trainingStatusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Training", icon: "dumbbell.fill", color: .accentColor)

            VStack(spacing: 0) {
                if settings.weeklyGoal > 0 {
                    let weekProgress = min(1.0, Double(workoutsThisWeek) / Double(settings.weeklyGoal))
                    let weekDone = workoutsThisWeek >= settings.weeklyGoal
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "target").foregroundStyle(weekDone ? Color.green : Color.accentColor)
                                Text("\(workoutsThisWeek)/\(settings.weeklyGoal) workouts this week").font(.subheadline)
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
                ForEach(Array(progressionSuggestions.enumerated()), id: \.element.id) { index, suggestion in
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
                    if index < progressionSuggestions.count - 1 { Divider().padding(.leading, 66) }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    // MARK: - Recent Workouts Card

    private var recentWorkoutsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Recent Workouts", icon: "clock.fill", color: .green)

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
                }

                Button { showingAddWorkout = true } label: {
                    quickLinkTile(icon: "plus.circle.fill", color: .accentColor, title: "Start Workout")
                }.buttonStyle(.plain)

                NavigationLink { ExerciseLibraryView() } label: {
                    quickLinkTile(icon: "books.vertical", color: .blue, title: "Exercise Library")
                }.buttonStyle(.plain)

                NavigationLink { InsightsView() } label: {
                    quickLinkTile(icon: "chart.bar", color: .green, title: "Insights")
                }.buttonStyle(.plain)

                if inProgressWorkout == nil {
                    NavigationLink { HealthDashboardView() } label: {
                        quickLinkTile(icon: "heart.text.square", color: .red, title: "Health")
                    }.buttonStyle(.plain)
                }
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
        let formatter = DateFormatter(); formatter.dateFormat = "MMM d"
        let newName = "\(last.name.components(separatedBy: " - ").first ?? last.name) - \(formatter.string(from: .now))"
        let workout = Workout(name: newName, date: .now)
        modelContext.insert(workout)
        for (index, oldExercise) in last.exercises.sorted(by: { $0.order < $1.order }).enumerated() {
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
}

#Preview {
    NavigationStack { HomeDashboardView() }
        .modelContainer(for: Workout.self, inMemory: true)
}
