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
        case home, training, health, more
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

    @State private var showingSettings = false

    private var iPhoneLayout: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house", value: .home) {
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
                                Button {
                                    showingSettings = true
                                } label: {
                                    Image(systemName: "gearshape")
                                }
                            }
                        }
                }
            }

            Tab("Training", systemImage: "figure.strengthtraining.traditional", value: .training) {
                NavigationStack {
                    trainingHubView
                        .navigationDestination(for: Workout.self) { workout in
                            WorkoutDetailView(workout: workout)
                        }
                        .navigationDestination(for: String.self) { exerciseName in
                            ExerciseHistoryView(exerciseName: exerciseName)
                        }
                }
            }

            Tab("Health", systemImage: "heart.text.square", value: .health) {
                NavigationStack {
                    healthHubView
                }
            }

            Tab("More", systemImage: "ellipsis.circle", value: .more) {
                NavigationStack {
                    moreHubView
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingSettings = false }
                        }
                    }
            }
        }
    }

    // MARK: - Training Hub

    private var totalFinishedWorkouts: Int {
        workouts.filter { $0.endTime != nil }.count
    }

    private var uniqueExerciseCount: Int {
        Set(workouts.filter { $0.endTime != nil }.flatMap { $0.exercises.map { $0.name.lowercased() } }).count
    }

    private var trainingHubView: some View {
        List {
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

            Section("Workouts") {
                NavigationLink {
                    FullWorkoutListView()
                } label: {
                    hubRow(icon: "dumbbell", color: .blue, title: "All Workouts", subtitle: "Complete workout history")
                }
                NavigationLink {
                    TrainingProgramsView()
                } label: {
                    hubRow(icon: "calendar.badge.clock", color: .purple, title: "Programs", subtitle: "Structured training plans")
                }
                NavigationLink {
                    WorkoutCalendarView()
                } label: {
                    hubRow(icon: "calendar", color: .teal, title: "Calendar", subtitle: "Monthly training view")
                }
            }

            Section("Analyze") {
                NavigationLink {
                    InsightsView()
                } label: {
                    hubRow(icon: "chart.bar", color: .green, title: "Insights", subtitle: "Training analytics & trends")
                }
                NavigationLink {
                    WorkoutComparisonView()
                } label: {
                    hubRow(icon: "arrow.left.arrow.right", color: .indigo, title: "Compare Workouts", subtitle: "Side-by-side analysis")
                }
                NavigationLink {
                    SmartSuggestionsView()
                } label: {
                    hubRow(icon: "brain.head.profile", color: .purple, title: "Smart Suggestions", subtitle: "AI-driven workout ideas")
                }
            }

            Section("Progress") {
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
                    LiftGoalsView()
                } label: {
                    hubRow(icon: "target", color: .green, title: "Lift Goals", subtitle: "Progressive overload targets")
                }
            }
        }
        .navigationTitle("Training")
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

    // MARK: - Health Hub

    private var healthHubView: some View {
        List {
            Section("Health") {
                NavigationLink {
                    HealthDashboardView()
                } label: {
                    hubRow(icon: "heart.text.square", color: .red, title: "Health Dashboard", subtitle: "Steps, heart rate, sleep & more")
                }
                NavigationLink {
                    CaffeineTrackerView()
                } label: {
                    hubRow(icon: "cup.and.saucer.fill", color: .brown, title: "Caffeine Tracker", subtitle: "Half-life decay & sleep readiness")
                }
                NavigationLink {
                    WaterTrackerView()
                } label: {
                    hubRow(icon: "drop.fill", color: .cyan, title: "Water Tracker", subtitle: "Daily hydration tracking")
                }
                NavigationLink {
                    CreatineTrackerView()
                } label: {
                    hubRow(icon: "pill.fill", color: .blue, title: "Creatine Tracker", subtitle: "Daily supplement tracking")
                }
            }

            Section("Body") {
                NavigationLink {
                    BodyWeightView()
                } label: {
                    hubRow(icon: "scalemass", color: .blue, title: "Body Weight", subtitle: "Weigh-ins & trend line")
                }
                NavigationLink {
                    BodyMeasurementsView()
                } label: {
                    hubRow(icon: "ruler", color: .teal, title: "Measurements", subtitle: "Body circumference tracking")
                }
                NavigationLink {
                    BodyFatEstimateView()
                } label: {
                    hubRow(icon: "percent", color: .indigo, title: "Body Fat %", subtitle: "Navy method estimation")
                }
                NavigationLink {
                    ProgressPhotosView()
                } label: {
                    hubRow(icon: "camera", color: .blue, title: "Progress Photos", subtitle: "Visual transformation")
                }
            }
        }
        .navigationTitle("Health")
    }

    // MARK: - More Hub

    private var moreHubView: some View {
        List {
            Section("Library") {
                NavigationLink {
                    ExerciseLibraryView()
                } label: {
                    hubRow(icon: "books.vertical", color: .blue, title: "Exercise Library", subtitle: "All your exercises")
                }
                NavigationLink {
                    AchievementsView()
                } label: {
                    hubRow(icon: "medal", color: .yellow, title: "Achievements", subtitle: "Badges and milestones")
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
            }

            Section("Activity") {
                NavigationLink {
                    ActivityLogView()
                } label: {
                    hubRow(icon: "figure.walk", color: .green, title: "Activity Log", subtitle: "Walks, rides, stretching, and more")
                }
            }

            Section("Timers") {
                NavigationLink {
                    WorkoutTimerView()
                } label: {
                    hubRow(icon: "timer", color: .red, title: "Workout Timers", subtitle: "EMOM, AMRAP, and Tabata")
                }
            }
        }
        .navigationTitle("More")
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
