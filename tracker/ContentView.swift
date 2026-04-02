import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Workout> { !$0.isTemplate }, sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]
    @Query private var settingsArray: [UserSettings]
    @State private var showingAddWorkout = false
    @State private var workoutToDelete: Workout?
    @State private var repeatConfirmation = false
    @State private var searchText = ""
    @State private var showingOnboarding = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // iPad
    @State private var selectedSidebarItem: SidebarItem? = .workouts

    // iPhone
    @State private var selectedTab: AppTab = .home

    // Filters
    @State private var filterDateRange: DateRange = .all
    @State private var filterMuscleGroup: MuscleGroup? = nil
    @State private var filterRating: Int? = nil

    enum AppTab: Hashable {
        case home, progress, insights, tools, settings
    }

    enum DateRange: String, CaseIterable {
        case all = "All Time"
        case week = "This Week"
        case month = "This Month"
        case threeMonths = "3 Months"
        case year = "This Year"
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
            case .settings: return "gearshape"
            }
        }
    }

    private var hasActiveFilters: Bool {
        filterDateRange != .all || filterMuscleGroup != nil || filterRating != nil
    }

    private var filteredWorkouts: [Workout] {
        var result = workouts

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { workout in
                workout.name.lowercased().contains(query)
                || workout.exercises.contains { $0.name.lowercased().contains(query) }
            }
        }

        if filterDateRange != .all {
            let cutoff = cutoffDate(for: filterDateRange)
            result = result.filter { $0.date >= cutoff }
        }

        if let group = filterMuscleGroup {
            result = result.filter { $0.exercises.contains { $0.category == group } }
        }

        if let rating = filterRating {
            result = result.filter { $0.rating == rating }
        }

        return result
    }

    private func cutoffDate(for range: DateRange) -> Date {
        let calendar = Calendar.current
        switch range {
        case .all: return .distantPast
        case .week: return calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        case .month: return calendar.dateInterval(of: .month, for: .now)?.start ?? .now
        case .threeMonths: return calendar.date(byAdding: .month, value: -3, to: .now) ?? .now
        case .year: return calendar.date(byAdding: .year, value: -1, to: .now) ?? .now
        }
    }

    private var settings: UserSettings {
        if let existing = settingsArray.first {
            return existing
        }
        let new = UserSettings()
        modelContext.insert(new)
        return new
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
                    workoutListView
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
                case .settings:
                    SettingsView()
                        .navigationTitle("Settings")
                }
            }
        }
    }

    // MARK: - iPhone Layout (TabView)

    private var iPhoneLayout: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "dumbbell", value: .home) {
                NavigationStack {
                    workoutListView
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

    // MARK: - Filter Chips

    @ViewBuilder
    private func filterChip(label: String, isActive: Bool, icon: String, @ViewBuilder menu: () -> some View) -> some View {
        menu()
    }

    private func filterChipLabel(label: String, isActive: Bool, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(label)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isActive ? Color.accentColor : Color(.tertiarySystemFill), in: Capsule())
        .foregroundStyle(isActive ? .white : .primary)
    }

    // MARK: - Workout List (shared)

    private var workoutListView: some View {
        List {
            if searchText.isEmpty && !workouts.isEmpty {
                if settings.weeklyGoal > 0 {
                    goalSection
                }
                streakSection
            }

            // Filter chips
            if !workouts.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            filterChip(
                                label: filterDateRange == .all ? "Date" : filterDateRange.rawValue,
                                isActive: filterDateRange != .all,
                                icon: "calendar"
                            ) {
                                Menu {
                                    ForEach(DateRange.allCases, id: \.self) { range in
                                        Button {
                                            filterDateRange = range
                                        } label: {
                                            if filterDateRange == range {
                                                Label(range.rawValue, systemImage: "checkmark")
                                            } else {
                                                Text(range.rawValue)
                                            }
                                        }
                                    }
                                } label: {
                                    filterChipLabel(
                                        label: filterDateRange == .all ? "Date" : filterDateRange.rawValue,
                                        isActive: filterDateRange != .all,
                                        icon: "calendar"
                                    )
                                }
                            }

                            filterChip(
                                label: filterMuscleGroup?.rawValue ?? "Muscle",
                                isActive: filterMuscleGroup != nil,
                                icon: "figure.strengthtraining.traditional"
                            ) {
                                Menu {
                                    Button {
                                        filterMuscleGroup = nil
                                    } label: {
                                        if filterMuscleGroup == nil {
                                            Label("All", systemImage: "checkmark")
                                        } else {
                                            Text("All")
                                        }
                                    }
                                    ForEach(MuscleGroup.allCases) { group in
                                        Button {
                                            filterMuscleGroup = group
                                        } label: {
                                            if filterMuscleGroup == group {
                                                Label(group.rawValue, systemImage: "checkmark")
                                            } else {
                                                Text(group.rawValue)
                                            }
                                        }
                                    }
                                } label: {
                                    filterChipLabel(
                                        label: filterMuscleGroup?.rawValue ?? "Muscle",
                                        isActive: filterMuscleGroup != nil,
                                        icon: "figure.strengthtraining.traditional"
                                    )
                                }
                            }

                            filterChip(
                                label: filterRating.map { "\($0)★" } ?? "Rating",
                                isActive: filterRating != nil,
                                icon: "star"
                            ) {
                                Menu {
                                    Button {
                                        filterRating = nil
                                    } label: {
                                        if filterRating == nil {
                                            Label("Any", systemImage: "checkmark")
                                        } else {
                                            Text("Any")
                                        }
                                    }
                                    ForEach(1...5, id: \.self) { stars in
                                        Button {
                                            filterRating = stars
                                        } label: {
                                            if filterRating == stars {
                                                Label(String(repeating: "★", count: stars), systemImage: "checkmark")
                                            } else {
                                                Text(String(repeating: "★", count: stars))
                                            }
                                        }
                                    }
                                } label: {
                                    filterChipLabel(
                                        label: filterRating.map { "\($0)★" } ?? "Rating",
                                        isActive: filterRating != nil,
                                        icon: "star"
                                    )
                                }
                            }

                            if hasActiveFilters {
                                Button {
                                    filterDateRange = .all
                                    filterMuscleGroup = nil
                                    filterRating = nil
                                } label: {
                                    Text("Clear")
                                        .font(.caption.bold())
                                        .foregroundStyle(.red)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(.red.opacity(0.1), in: Capsule())
                                }
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            }

            if !filteredWorkouts.isEmpty {
                Section {
                    ForEach(filteredWorkouts) { workout in
                        NavigationLink(value: workout) {
                            workoutCard(workout)
                        }
                    }
                    .onDelete { offsets in
                        if let index = offsets.first {
                            workoutToDelete = filteredWorkouts[index]
                        }
                    }
                } header: {
                    HStack {
                        Text(hasActiveFilters ? "Filtered Workouts" : "Recent Workouts")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                        if hasActiveFilters {
                            Spacer()
                            Text("\(filteredWorkouts.count)")
                                .font(.caption.bold().monospacedDigit())
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            } else if hasActiveFilters {
                ContentUnavailableView {
                    Label("No Matches", systemImage: "line.3.horizontal.decrease.circle")
                } description: {
                    Text("No workouts match your current filters.")
                } actions: {
                    Button("Clear Filters") {
                        filterDateRange = .all
                        filterMuscleGroup = nil
                        filterRating = nil
                    }
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if workouts.isEmpty {
                ContentUnavailableView {
                    Label("No Workouts Yet", systemImage: "dumbbell.fill")
                } description: {
                    Text("Tap the + button to log your first workout and start tracking your progress.")
                } actions: {
                    Button {
                        showingAddWorkout = true
                    } label: {
                        Text("Start Workout")
                            .font(.subheadline.bold())
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if filteredWorkouts.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .navigationTitle("Metricly")
        .searchable(text: $searchText, prompt: "Search workouts or exercises")
        .navigationDestination(for: Workout.self) { workout in
            WorkoutDetailView(workout: workout)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    if let lastWorkout = workouts.first, !lastWorkout.exercises.isEmpty {
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
    }

    private var goalProgress: Double {
        guard settings.weeklyGoal > 0 else { return 0 }
        return min(1.0, Double(workoutsThisWeek) / Double(settings.weeklyGoal))
    }

    private var goalSection: some View {
        Section {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.accentColor.opacity(0.2), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: goalProgress)
                        .stroke(
                            goalProgress >= 1.0 ? Color.green : Color.accentColor,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: goalProgress)
                    VStack(spacing: 0) {
                        Text("\(workoutsThisWeek)")
                            .font(.title2.bold().monospacedDigit())
                        Text("/\(settings.weeklyGoal)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 4) {
                    if workoutsThisWeek >= settings.weeklyGoal {
                        Text("Goal reached!")
                            .font(.headline)
                            .foregroundStyle(.green)
                    } else {
                        Text("\(settings.weeklyGoal - workoutsThisWeek) more to go")
                            .font(.headline)
                    }
                    Text("Weekly goal: \(settings.weeklyGoal) workouts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Weekly goal: \(workoutsThisWeek) of \(settings.weeklyGoal) workouts completed")
        }
    }

    private var streakSection: some View {
        Section {
            NavigationLink {
                StreakCalendarView()
            } label: {
                HStack(spacing: 20) {
                    statBubble(
                        value: "\(workoutsThisWeek)",
                        label: "This Week",
                        icon: "flame.fill",
                        color: workoutsThisWeek > 0 ? .orange : .secondary
                    )
                    Divider()
                        .frame(height: 40)
                    statBubble(
                        value: "\(currentStreak)",
                        label: "Day Streak",
                        icon: "bolt.fill",
                        color: currentStreak >= 3 ? .yellow : .secondary
                    )
                    Divider()
                        .frame(height: 40)
                    statBubble(
                        value: "\(workouts.count)",
                        label: "Total",
                        icon: "figure.strengthtraining.traditional",
                        color: Color.accentColor
                    )
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
        }
    }

    private func statBubble(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.caption)
                Text(value)
                    .font(.title2.bold().monospacedDigit())
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    private var workoutsThisWeek: Int {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return 0 }
        return workouts.filter { $0.date >= weekStart }.count
    }

    private var currentStreak: Int {
        let calendar = Calendar.current
        let workoutDays = Set(workouts.map { calendar.startOfDay(for: $0.date) })
        guard !workoutDays.isEmpty else { return 0 }

        var streak = 0
        var checkDate = calendar.startOfDay(for: .now)

        // If no workout today, start checking from yesterday
        if !workoutDays.contains(checkDate) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }

        while workoutDays.contains(checkDate) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }
        return streak
    }

    private func workoutCard(_ workout: Workout) -> some View {
        HStack(spacing: 0) {
            // Status accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(workout.isFinished ? Color.green : Color.accentColor)
                .frame(width: 4, height: 44)
                .padding(.trailing, 12)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(workout.name)
                        .font(.headline)
                    Spacer()
                    if !workout.isFinished {
                        Text("In Progress")
                            .font(.caption2.bold())
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.12), in: .capsule)
                    }
                }

                HStack(spacing: 8) {
                    Label(workout.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()),
                          systemImage: "calendar")
                    if let duration = workout.formattedDuration {
                        Label(duration, systemImage: "clock")
                    }
                    if let rating = workout.rating, rating > 0 {
                        HStack(spacing: 1) {
                            ForEach(1...rating, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .imageScale(.small)
                            }
                        }
                        .foregroundStyle(.yellow)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if !workout.exercises.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(workout.exercises.sorted { $0.order < $1.order }.prefix(3)) { exercise in
                            HStack(spacing: 3) {
                                Image(systemName: exercise.category?.icon ?? "dumbbell")
                                    .font(.system(size: 9))
                                Text(exercise.name)
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.tertiarySystemFill), in: .capsule)
                        }
                        if workout.exercises.count > 3 {
                            Text("+\(workout.exercises.count - 3)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(workoutAccessibilityLabel(workout))
    }

    private func workoutAccessibilityLabel(_ workout: Workout) -> String {
        var parts = [workout.name]
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        parts.append(dateFormatter.string(from: workout.date))
        if let duration = workout.formattedDuration {
            parts.append("Duration \(duration)")
        }
        if !workout.exercises.isEmpty {
            parts.append("\(workout.exercises.count) exercises")
        }
        return parts.joined(separator: ", ")
    }

    private func workoutSummary(_ workout: Workout) -> String {
        let exerciseNames = workout.exercises.map(\.name)
        let totalSets = workout.exercises.reduce(0) { $0 + $1.sets.count }
        let names = exerciseNames.prefix(3).joined(separator: ", ")
        let suffix = exerciseNames.count > 3 ? " +\(exerciseNames.count - 3) more" : ""
        return "\(names)\(suffix) \u{00B7} \(totalSets) set\(totalSets == 1 ? "" : "s")"
    }

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

    private func deleteWorkouts(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(workouts[index])
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Workout.self, inMemory: true)
}
