import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Workout> { !$0.isTemplate }, sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]
    @Query private var settingsArray: [UserSettings]
    @State private var showingAddWorkout = false
    @State private var showingSettings = false
    @State private var showingVolume = false
    @State private var workoutToDelete: Workout?
    @State private var repeatConfirmation = false
    @State private var searchText = ""
    @State private var showingOnboarding = false
    @State private var showingBodyWeight = false
    @State private var showingCalendar = false

    private var filteredWorkouts: [Workout] {
        if searchText.isEmpty { return workouts }
        let query = searchText.lowercased()
        return workouts.filter { workout in
            workout.name.lowercased().contains(query)
            || workout.exercises.contains { $0.name.lowercased().contains(query) }
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

    var body: some View {
        NavigationStack {
            List {
                if searchText.isEmpty && !workouts.isEmpty {
                    streakSection
                }
                ForEach(filteredWorkouts) { workout in
                    NavigationLink(value: workout) {
                        HStack(spacing: 14) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.title2)
                                .foregroundStyle(.tint)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(workout.name)
                                    .font(.headline)
                                HStack(spacing: 6) {
                                    Text(workout.date, format: .dateTime.weekday(.wide).month().day())
                                    if let duration = workout.formattedDuration {
                                        Text("·")
                                        Image(systemName: "clock")
                                            .imageScale(.small)
                                        Text(duration)
                                    }
                                    if let rating = workout.rating, rating > 0 {
                                        Text("·")
                                        HStack(spacing: 1) {
                                            ForEach(1...rating, id: \.self) { _ in
                                                Image(systemName: "star.fill")
                                                    .imageScale(.small)
                                            }
                                        }
                                        .foregroundStyle(.yellow)
                                    }
                                }
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                if !workout.exercises.isEmpty {
                                    Text(workoutSummary(workout))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(workoutAccessibilityLabel(workout))
                    }
                }
                .onDelete { offsets in
                    if let index = offsets.first {
                        workoutToDelete = filteredWorkouts[index]
                    }
                }
            }
            .overlay {
                if workouts.isEmpty {
                    ContentUnavailableView {
                        Label("No Workouts", systemImage: "dumbbell")
                    } description: {
                        Text("Tap + to log your first workout.")
                    }
                } else if filteredWorkouts.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .navigationTitle("Workouts")
            .searchable(text: $searchText, prompt: "Search workouts or exercises")
            .navigationDestination(for: Workout.self) { workout in
                WorkoutDetailView(workout: workout)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 16) {
                        Button {
                            showingSettings = true
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                        Menu {
                            Button {
                                showingCalendar = true
                            } label: {
                                Label("Calendar", systemImage: "calendar")
                            }
                            Button {
                                showingVolume = true
                            } label: {
                                Label("Volume", systemImage: "chart.bar")
                            }
                            Button {
                                showingBodyWeight = true
                            } label: {
                                Label("Body Weight", systemImage: "scalemass")
                            }
                        } label: {
                            Label("Charts", systemImage: "chart.bar")
                        }
                    }
                }
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
            }
            .sheet(isPresented: $showingVolume) {
                NavigationStack {
                    VolumeChartView()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showingVolume = false }
                            }
                        }
                }
                .environment(\.weightUnit, weightUnit)
            }
            .sheet(isPresented: $showingCalendar) {
                NavigationStack {
                    WorkoutCalendarView()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showingCalendar = false }
                            }
                        }
                }
                .environment(\.weightUnit, weightUnit)
            }
            .sheet(isPresented: $showingBodyWeight) {
                NavigationStack {
                    BodyWeightView()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showingBodyWeight = false }
                            }
                        }
                }
                .environment(\.weightUnit, weightUnit)
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
                .environment(\.weightUnit, weightUnit)
            }
        }
        .environment(\.weightUnit, weightUnit)
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

    private var streakSection: some View {
        Section {
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
                    label: streakLabel,
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

    private var streakLabel: String {
        currentStreak == 1 ? "Day Streak" : "Day Streak"
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
