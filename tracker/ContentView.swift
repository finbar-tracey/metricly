import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Workout> { !$0.isTemplate }, sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]
    @Query private var settingsArray: [UserSettings]
    @State private var workoutToDelete: Workout?
    @State private var repeatConfirmation = false
    @State private var showingOnboarding = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // iPad
    @State private var selectedSidebarItem: SidebarItem? = .workouts

    // iPhone
    @State private var selectedTab: AppTab = .home

    enum AppTab: Hashable {
        case home, progress, insights, tools, settings
    }

    enum SidebarItem: String, Hashable, CaseIterable {
        case workouts = "Workouts"
        case programs = "Programs"
        case calendar = "Calendar"
        case achievements = "Achievements"
        case streak = "Streak"
        case personalRecords = "Personal Records"
        case progressPhotos = "Progress Photos"
        case measurements = "Measurements"
        case liftGoals = "Lift Goals"
        case insights = "Insights"
        case exerciseLibrary = "Exercise Library"
        case comparison = "Compare"
        case plateCalculator = "Plate Calculator"
        case oneRepMax = "1RM Calculator"
        case workoutTimers = "Workout Timers"
        case caffeineTracker = "Caffeine Tracker"
        case bodyFat = "Body Fat %"
        case health = "Health"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .workouts: return "dumbbell"
            case .programs: return "calendar.badge.clock"
            case .calendar: return "calendar"
            case .achievements: return "medal"
            case .streak: return "flame"
            case .personalRecords: return "trophy"
            case .progressPhotos: return "camera"
            case .measurements: return "ruler"
            case .liftGoals: return "target"
            case .insights: return "chart.bar"
            case .exerciseLibrary: return "books.vertical"
            case .comparison: return "arrow.left.arrow.right"
            case .plateCalculator: return "circle.grid.cross"
            case .oneRepMax: return "function"
            case .workoutTimers: return "timer"
            case .caffeineTracker: return "cup.and.saucer.fill"
            case .bodyFat: return "percent"
            case .health: return "heart.text.square"
            case .settings: return "gearshape"
            }
        }
    }

    private var settings: UserSettings {
        settingsArray.first ?? UserSettings()
    }

    private var weightUnit: WeightUnit {
        (settingsArray.first?.useKilograms ?? true) ? .kg : .lbs
    }

    private var accentColor: Color {
        switch settingsArray.first?.accentColorName ?? "blue" {
        case "indigo": return .indigo
        case "purple": return .purple
        case "pink": return .pink
        case "red": return .red
        case "orange": return .orange
        case "green": return .green
        case "teal": return .teal
        default: return .blue
        }
    }

    private var resolvedColorScheme: ColorScheme? {
        switch settingsArray.first?.appearanceMode ?? "system" {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .tint(accentColor)
        .environment(\.weightUnit, weightUnit)
        .preferredColorScheme(resolvedColorScheme)
        .alert("Repeat Last Workout?", isPresented: $repeatConfirmation) {
            Button("Repeat") {
                repeatLastWorkout()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let last = workouts.first {
                Text("Create a new workout with the same exercises as \"\(last.name)\"?")
            }
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView {
                settings.hasSeenOnboarding = true
            }
        }
        .onAppear {
            if !settings.hasSeenOnboarding {
                showingOnboarding = true
            }
        }
        .alert("Delete Workout?", isPresented: Binding(
            get: { workoutToDelete != nil },
            set: { if !$0 { workoutToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let workout = workoutToDelete {
                    modelContext.delete(workout)
                    workoutToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { workoutToDelete = nil }
        } message: {
            if let workout = workoutToDelete {
                Text("Are you sure you want to delete \"\(workout.name)\"? This cannot be undone.")
            }
        }
    }

    // MARK: - iPad Layout

    private var iPadLayout: some View {
        NavigationSplitView {
            List(selection: $selectedSidebarItem) {
                Section("Track") {
                    Label("Workouts", systemImage: "dumbbell")
                        .tag(SidebarItem.workouts)
                    Label("Programs", systemImage: "calendar.badge.clock")
                        .tag(SidebarItem.programs)
                    Label("Calendar", systemImage: "calendar")
                        .tag(SidebarItem.calendar)
                    Label("Progress Photos", systemImage: "camera")
                        .tag(SidebarItem.progressPhotos)
                }
                Section("Progress") {
                    Label("Achievements", systemImage: "medal")
                        .tag(SidebarItem.achievements)
                    Label("Streak", systemImage: "flame")
                        .tag(SidebarItem.streak)
                    Label("Personal Records", systemImage: "trophy")
                        .tag(SidebarItem.personalRecords)
                    Label("Measurements", systemImage: "ruler")
                        .tag(SidebarItem.measurements)
                    Label("Body Fat %", systemImage: "percent")
                        .tag(SidebarItem.bodyFat)
                    Label("Health", systemImage: "heart.text.square")
                        .tag(SidebarItem.health)
                    Label("Lift Goals", systemImage: "target")
                        .tag(SidebarItem.liftGoals)
                }
                Section("Analyze") {
                    Label("Insights", systemImage: "chart.bar")
                        .tag(SidebarItem.insights)
                    Label("Exercise Library", systemImage: "books.vertical")
                        .tag(SidebarItem.exerciseLibrary)
                    Label("Compare", systemImage: "arrow.left.arrow.right")
                        .tag(SidebarItem.comparison)
                }
                Section("Tools") {
                    Label("Plate Calculator", systemImage: "circle.grid.cross")
                        .tag(SidebarItem.plateCalculator)
                    Label("1RM Calculator", systemImage: "function")
                        .tag(SidebarItem.oneRepMax)
                    Label("Workout Timers", systemImage: "timer")
                        .tag(SidebarItem.workoutTimers)
                    Label("Caffeine Tracker", systemImage: "cup.and.saucer.fill")
                        .tag(SidebarItem.caffeineTracker)
                }
                Section {
                    Label("Settings", systemImage: "gearshape")
                        .tag(SidebarItem.settings)
                }
            }
            .navigationTitle("Metricly")
        } detail: {
            NavigationStack {
                switch selectedSidebarItem {
                case .workouts, .none:
                    HomeDashboardView()
                case .programs:
                    TrainingProgramsView()
                        .navigationTitle("Programs")
                case .calendar:
                    WorkoutCalendarView()
                        .navigationTitle("Calendar")
                case .progressPhotos:
                    ProgressPhotosView()
                case .achievements:
                    AchievementsView()
                case .streak:
                    StreakCalendarView()
                case .personalRecords:
                    PersonalRecordsView()
                case .measurements:
                    BodyMeasurementsView()
                case .liftGoals:
                    LiftGoalsView()
                case .insights:
                    InsightsView()
                        .navigationTitle("Insights")
                case .exerciseLibrary:
                    ExerciseLibraryView()
                        .navigationTitle("Exercise Library")
                case .comparison:
                    WorkoutComparisonView()
                        .navigationTitle("Compare Workouts")
                case .plateCalculator:
                    PlateCalculatorView()
                case .oneRepMax:
                    OneRepMaxView()
                case .workoutTimers:
                    WorkoutTimerView()
                case .caffeineTracker:
                    CaffeineTrackerView()
                case .bodyFat:
                    BodyFatEstimateView()
                case .health:
                    HealthDashboardView()
                case .settings:
                    SettingsView()
                        .navigationTitle("Settings")
                }
            }
            .navigationDestination(for: Workout.self) { workout in
                WorkoutDetailView(workout: workout)
            }
            .navigationDestination(for: String.self) { exerciseName in
                ExerciseHistoryView(exerciseName: exerciseName)
            }
        }
    }

    // MARK: - iPhone Layout (TabView)

    private var iPhoneLayout: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "dumbbell", value: .home) {
                NavigationStack {
                    HomeDashboardView()
                        .navigationDestination(for: Workout.self) { workout in
                            WorkoutDetailView(workout: workout)
                        }
                        .navigationDestination(for: String.self) { exerciseName in
                            ExerciseHistoryView(exerciseName: exerciseName)
                        }
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Menu {
                                    NavigationLink {
                                        WorkoutCalendarView()
                                    } label: {
                                        Label("Calendar", systemImage: "calendar")
                                    }
                                    NavigationLink {
                                        TrainingProgramsView()
                                    } label: {
                                        Label("Programs", systemImage: "calendar.badge.clock")
                                    }
                                } label: {
                                    Label("More", systemImage: "calendar")
                                }
                            }
                        }
                }
            }

            Tab("Progress", systemImage: "trophy", value: .progress) {
                NavigationStack {
                    progressHubView
                }
            }

            Tab("Insights", systemImage: "chart.bar", value: .insights) {
                NavigationStack {
                    InsightsView()
                }
            }

            Tab("Tools", systemImage: "wrench.and.screwdriver", value: .tools) {
                NavigationStack {
                    toolsHubView
                }
            }

            Tab("Settings", systemImage: "gearshape", value: .settings) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
    }

    // MARK: - Progress Hub

    private var totalFinishedWorkouts: Int {
        workouts.filter { $0.endTime != nil }.count
    }

    private var uniqueExerciseCount: Int {
        Set(workouts.filter { $0.endTime != nil }.flatMap { $0.exercises.map { $0.name.lowercased() } }).count
    }

    private var progressHubView: some View {
        List {
            // Quick stats overview
            Section {
                HStack(spacing: 0) {
                    progressStat(value: "\(totalFinishedWorkouts)", label: "Workouts", icon: "figure.strengthtraining.traditional", color: .blue)
                    Divider().frame(height: 32)
                    progressStat(value: "\(currentStreak)", label: "Streak", icon: "flame.fill", color: .orange)
                    Divider().frame(height: 32)
                    progressStat(value: "\(uniqueExerciseCount)", label: "Exercises", icon: "dumbbell.fill", color: .purple)
                }
                .padding(.vertical, 8)
            }

            Section {
                NavigationLink {
                    HealthDashboardView()
                } label: {
                    hubRow(icon: "heart.text.square", color: .red, title: "Health", subtitle: "Steps, heart rate, sleep & more")
                }
                NavigationLink {
                    AchievementsView()
                } label: {
                    hubRow(icon: "medal", color: .yellow, title: "Achievements", subtitle: "Badges and milestones")
                }
                NavigationLink {
                    PersonalRecordsView()
                } label: {
                    hubRow(icon: "trophy", color: .orange, title: "Personal Records", subtitle: "Your heaviest lifts")
                }
                NavigationLink {
                    StreakCalendarView()
                } label: {
                    hubRow(icon: "flame", color: .red, title: "Streak", subtitle: "Workout consistency")
                }
                NavigationLink {
                    ProgressPhotosView()
                } label: {
                    hubRow(icon: "camera", color: .blue, title: "Progress Photos", subtitle: "Visual transformation")
                }
                NavigationLink {
                    BodyMeasurementsView()
                } label: {
                    hubRow(icon: "ruler", color: .teal, title: "Measurements", subtitle: "Body circumference tracking")
                }
                NavigationLink {
                    LiftGoalsView()
                } label: {
                    hubRow(icon: "target", color: .green, title: "Lift Goals", subtitle: "Progressive overload targets")
                }
            }
        }
        .navigationTitle("Progress")
    }

    private func progressStat(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tools Hub

    private var toolsSuggestionTeaser: String {
        let calendar = Calendar.current
        let finishedWorkouts = workouts.filter { $0.endTime != nil }

        // Simple logic: check which broad category is most rested
        let pushGroups: Set<MuscleGroup> = [.chest, .shoulders, .triceps]
        let pullGroups: Set<MuscleGroup> = [.back, .biceps]
        let legGroups: Set<MuscleGroup> = [.legs]

        func daysSinceLast(_ groups: Set<MuscleGroup>) -> Int {
            for w in finishedWorkouts.sorted(by: { $0.date > $1.date }) {
                if w.exercises.contains(where: { groups.contains($0.category ?? .other) }) {
                    return calendar.dateComponents([.day], from: w.date, to: .now).day ?? 999
                }
            }
            return 999
        }

        let pushDays = daysSinceLast(pushGroups)
        let pullDays = daysSinceLast(pullGroups)
        let legDays = daysSinceLast(legGroups)
        let maxDays = max(pushDays, pullDays, legDays)

        if maxDays == 999 { return "Start training to get suggestions" }
        if maxDays == legDays { return "Legs are most rested — leg day?" }
        if maxDays == pullDays { return "Pull muscles are fresh — back & biceps?" }
        return "Push muscles are ready — chest & shoulders?"
    }

    private var toolsHubView: some View {
        List {
            // Quick suggestion teaser
            Section {
                NavigationLink {
                    SmartSuggestionsView()
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.purple.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.purple)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Today's Suggestion")
                                .font(.subheadline.weight(.semibold))
                            Text(toolsSuggestionTeaser)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Library") {
                NavigationLink {
                    ExerciseLibraryView()
                } label: {
                    hubRow(icon: "books.vertical", color: .blue, title: "Exercise Library", subtitle: "All your exercises")
                }
                NavigationLink {
                    WorkoutComparisonView()
                } label: {
                    hubRow(icon: "arrow.left.arrow.right", color: .green, title: "Compare Workouts", subtitle: "Side-by-side analysis")
                }
            }
            Section("Calculators") {
                NavigationLink {
                    PlateCalculatorView()
                } label: {
                    hubRow(icon: "circle.grid.cross", color: .orange, title: "Plate Calculator", subtitle: "Barbell plate loading")
                }
                NavigationLink {
                    OneRepMaxView()
                } label: {
                    hubRow(icon: "function", color: .teal, title: "1RM Calculator", subtitle: "Estimated one-rep max")
                }
                NavigationLink {
                    BodyFatEstimateView()
                } label: {
                    hubRow(icon: "percent", color: .indigo, title: "Body Fat %", subtitle: "Navy method estimation")
                }
            }
            Section("Timers") {
                NavigationLink {
                    WorkoutTimerView()
                } label: {
                    hubRow(icon: "timer", color: .red, title: "Workout Timers", subtitle: "EMOM, AMRAP, and Tabata")
                }
            }
            Section("Tracking") {
                NavigationLink {
                    CaffeineTrackerView()
                } label: {
                    hubRow(icon: "cup.and.saucer.fill", color: .brown, title: "Caffeine Tracker", subtitle: "Half-life decay & sleep readiness")
                }
            }
        }
        .navigationTitle("Tools")
    }

    private func hubRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.gradient)
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var currentStreak: Int {
        Workout.currentStreak(from: workouts)
    }

    // MARK: - Actions

    private func repeatLastWorkout() {
        guard let last = workouts.first else { return }
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

}

#Preview {
    ContentView()
        .modelContainer(for: Workout.self, inMemory: true)
}
