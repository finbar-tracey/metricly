import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Workout> { !$0.isTemplate }, sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]
    @Query(sort: \CardioSession.date, order: .reverse) private var cardioSessions: [CardioSession]
    @Query private var settingsArray: [UserSettings]
    @State private var workoutToDelete: Workout?
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
        // Track
        case workouts = "Workouts"
        case programs = "Programs"
        case schedule = "Schedule"
        case calendar = "Calendar"
        case cardio = "Cardio"
        case activityLog = "Activity Log"
        // Progress
        case achievements = "Achievements"
        case streak = "Streak"
        case personalRecords = "Personal Records"
        case progressPhotos = "Progress Photos"
        case measurements = "Measurements"
        case bodyWeight = "Body Weight"
        case bodyFat = "Body Fat %"
        case liftGoals = "Lift Goals"
        // Health
        case health = "Health"
        case water = "Water"
        case caffeine = "Caffeine"
        case creatine = "Creatine"
        // Analyze
        case insights = "Insights"
        case exerciseLibrary = "Exercise Library"
        case comparison = "Compare"
        case smartSuggestions = "Smart Suggestions"
        // Tools
        case plateCalculator = "Plate Calculator"
        case oneRepMax = "1RM Calculator"
        case workoutTimers = "Workout Timers"
        // Settings
        case settings = "Settings"

        var icon: String {
            switch self {
            case .workouts:         return "dumbbell"
            case .programs:         return "calendar.badge.clock"
            case .schedule:         return "calendar.badge.checkmark"
            case .calendar:         return "calendar"
            case .cardio:           return "figure.run"
            case .activityLog:      return "list.bullet.rectangle"
            case .achievements:     return "medal"
            case .streak:           return "flame"
            case .personalRecords:  return "trophy"
            case .progressPhotos:   return "camera"
            case .measurements:     return "ruler"
            case .bodyWeight:       return "scalemass"
            case .liftGoals:        return "target"
            case .insights:         return "chart.bar"
            case .exerciseLibrary:  return "books.vertical"
            case .comparison:       return "arrow.left.arrow.right"
            case .smartSuggestions: return "lightbulb"
            case .plateCalculator:  return "circle.grid.cross"
            case .oneRepMax:        return "function"
            case .workoutTimers:    return "timer"
            case .caffeine:         return "cup.and.saucer.fill"
            case .bodyFat:          return "percent"
            case .health:           return "heart.text.square"
            case .water:            return "drop.fill"
            case .creatine:         return "pill.fill"
            case .settings:         return "gearshape"
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
        (settingsArray.first?.accentColor ?? .blue).color
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
        .fullScreenCover(isPresented: $showingOnboarding) {
            OnboardingView {
                settings.hasSeenOnboarding = true
            }
        }
        .onAppear {
            if !settings.hasSeenOnboarding {
                showingOnboarding = true
            }
            // Schedule streak nudges based on saved reminder days
            let reminderDays = settings.reminderDays
            if !reminderDays.isEmpty {
                ReminderManager.scheduleStreakNudges(days: reminderDays)
            }
            // Push today's scheduled workout name to the Today's Plan widget
            let weekday = Calendar.current.component(.weekday, from: Date())
            let scheduled = settings.weeklyPlan[weekday] ?? ""
            let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .distantPast
            let activitiesThisWeek = workouts.filter { $0.date >= weekStart }.count
                                   + cardioSessions.filter { $0.date >= weekStart }.count
            WidgetDataWriter.update(
                streakDays: Workout.currentStreak(from: workouts, cardioSessions: cardioSessions),
                todayWorkoutName: workouts.first(where: { Calendar.current.isDateInToday($0.date) })?.name ?? "",
                weeklyCardioKm: 0,
                lastRunPace: "",
                lastRunDist: "",
                weeklyGoal: settings.weeklyGoal,
                workoutsThisWeek: activitiesThisWeek,
                weeklyCardioGoalKm: settings.weeklyCardioDistanceGoalKm,
                todayScheduledName: scheduled
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .openTrainingTab)) { _ in
            withAnimation { selectedTab = .training }
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
                    Label("Workouts",     systemImage: "dumbbell")                  .tag(SidebarItem.workouts)
                    Label("Programs",     systemImage: "calendar.badge.clock")      .tag(SidebarItem.programs)
                    Label("Schedule",     systemImage: "calendar.badge.checkmark")  .tag(SidebarItem.schedule)
                    Label("Calendar",     systemImage: "calendar")                  .tag(SidebarItem.calendar)
                    Label("Cardio",       systemImage: "figure.run")                .tag(SidebarItem.cardio)
                    Label("Activity Log", systemImage: "list.bullet.rectangle")     .tag(SidebarItem.activityLog)
                }
                Section("Progress") {
                    Label("Achievements",      systemImage: "medal")               .tag(SidebarItem.achievements)
                    Label("Streak",            systemImage: "flame")               .tag(SidebarItem.streak)
                    Label("Personal Records",  systemImage: "trophy")              .tag(SidebarItem.personalRecords)
                    Label("Progress Photos",   systemImage: "camera")              .tag(SidebarItem.progressPhotos)
                    Label("Measurements",      systemImage: "ruler")               .tag(SidebarItem.measurements)
                    Label("Body Weight",       systemImage: "scalemass")           .tag(SidebarItem.bodyWeight)
                    Label("Body Fat %",        systemImage: "percent")             .tag(SidebarItem.bodyFat)
                    Label("Lift Goals",        systemImage: "target")              .tag(SidebarItem.liftGoals)
                }
                Section("Health") {
                    Label("Health Dashboard",  systemImage: "heart.text.square")   .tag(SidebarItem.health)
                    Label("Water",             systemImage: "drop.fill")           .tag(SidebarItem.water)
                    Label("Caffeine",          systemImage: "cup.and.saucer.fill") .tag(SidebarItem.caffeine)
                    Label("Creatine",          systemImage: "pill.fill")           .tag(SidebarItem.creatine)
                }
                Section("Analyze") {
                    Label("Insights",          systemImage: "chart.bar")               .tag(SidebarItem.insights)
                    Label("Exercise Library",  systemImage: "books.vertical")          .tag(SidebarItem.exerciseLibrary)
                    Label("Compare Workouts",  systemImage: "arrow.left.arrow.right")  .tag(SidebarItem.comparison)
                    Label("Smart Suggestions", systemImage: "lightbulb")               .tag(SidebarItem.smartSuggestions)
                }
                Section("Tools") {
                    Label("Plate Calculator",  systemImage: "circle.grid.cross") .tag(SidebarItem.plateCalculator)
                    Label("1RM Calculator",    systemImage: "function")          .tag(SidebarItem.oneRepMax)
                    Label("Workout Timers",    systemImage: "timer")             .tag(SidebarItem.workoutTimers)
                }
                Section {
                    Label("Settings", systemImage: "gearshape").tag(SidebarItem.settings)
                }
            }
            .navigationTitle("Metricly")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingSearch = true } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
            .sheet(isPresented: $showingSearch) { GlobalSearchView() }
        } detail: {
            NavigationStack {
                switch selectedSidebarItem {
                case .workouts, .none:  HomeDashboardView()
                case .programs:         TrainingProgramsView().navigationTitle("Programs")
                case .schedule:         WorkoutScheduleView()
                case .calendar:         WorkoutCalendarView().navigationTitle("Calendar")
                case .cardio:           CardioHubView()
                case .activityLog:      ActivityLogView().navigationTitle("Activity Log")
                case .achievements:     AchievementsView()
                case .streak:           StreakCalendarView()
                case .personalRecords:  PersonalRecordsView()
                case .progressPhotos:   ProgressPhotosView()
                case .measurements:     BodyMeasurementsView()
                case .bodyWeight:       BodyWeightView()
                case .bodyFat:          BodyFatEstimateView()
                case .liftGoals:        LiftGoalsView()
                case .health:           HealthDashboardView()
                case .water:            WaterTrackerView()
                case .caffeine:         CaffeineTrackerView()
                case .creatine:         CreatineTrackerView()
                case .insights:         InsightsView().navigationTitle("Insights")
                case .exerciseLibrary:  ExerciseLibraryView().navigationTitle("Exercise Library")
                case .comparison:       WorkoutComparisonView().navigationTitle("Compare Workouts")
                case .smartSuggestions: SmartSuggestionsView()
                case .plateCalculator:  PlateCalculatorView()
                case .oneRepMax:        OneRepMaxView()
                case .workoutTimers:    WorkoutTimerView()
                case .settings:         SettingsView().navigationTitle("Settings")
                }
            }
            .navigationDestination(for: Workout.self) { workout in WorkoutDetailView(workout: workout) }
            .navigationDestination(for: String.self)  { name in ExerciseHistoryView(exerciseName: name) }
        }
    }

    // MARK: - iPhone Layout (TabView)

    @State private var showingSettings = false
    @State private var showingSearch = false

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
                            ToolbarItem(placement: .topBarTrailing) {
                                Button {
                                    showingSearch = true
                                } label: {
                                    Image(systemName: "magnifyingglass")
                                }
                            }
                        }
                        .sheet(isPresented: $showingSearch) {
                            GlobalSearchView()
                        }
                }
            }

            Tab("Training", systemImage: "figure.strengthtraining.traditional", value: .training) {
                NavigationStack {
                    TrainingHubView()
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
                    HealthHubView()
                }
            }

            Tab("More", systemImage: "ellipsis.circle", value: .more) {
                NavigationStack {
                    MoreHubView()
                        .navigationDestination(for: String.self) { exerciseName in
                            ExerciseHistoryView(exerciseName: exerciseName)
                        }
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

}


#Preview {
    ContentView()
        .modelContainer(for: Workout.self, inMemory: true)
}
