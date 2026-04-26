import SwiftUI
import SwiftData
import UIKit

struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.weightUnit) private var weightUnit
    @Environment(\.scenePhase) private var scenePhase
    @Query private var allExercises: [Exercise]
    let workout: Workout
    @State private var newExerciseName = ""
    @State private var newExerciseCategory: MuscleGroup = .other
    @State private var showingEditWorkout = false
    @State private var showTemplateSaved = false
    @State private var showingSuggestions = false
    @State private var exerciseToDelete: Exercise?
    @State private var elapsedTime = ""
    @State private var durationTimer: Timer?
    @State private var linkingSupersetFor: Exercise?
    @State private var showingFinishSheet = false
    @State private var showingShare = false
    @State private var shareItems: [Any] = []
    @State private var showDeleteConfirm = false
    @State private var showWorkoutTimer = false
    @State private var showFocusPrompt = false
    @State private var showFocusEndReminder = false
    @Query private var settingsArray: [UserSettings]
    @Environment(\.dismiss) private var dismiss

    private var settings: UserSettings {
        settingsArray.first ?? UserSettings()
    }

    private var suggestions: [String] {
        let history = Set(allExercises.map(\.name))
        let current = Set(workout.exercises.map(\.name))
        let available = history.subtracting(current)
        if newExerciseName.isEmpty {
            return available.sorted()
        }
        return available.filter {
            $0.localizedCaseInsensitiveContains(newExerciseName)
        }.sorted()
    }

    var body: some View {
        List {
            if !workout.isTemplate {
                Section {
                    VStack(spacing: 12) {
                        // Status row
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(workout.isFinished ? Color.green.opacity(0.15) : Color.accentColor.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Image(systemName: workout.isFinished ? "checkmark.circle.fill" : "timer")
                                    .font(.system(size: 18))
                                    .foregroundStyle(workout.isFinished ? .green : Color.accentColor)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(workout.isFinished ? "Completed" : "In Progress")
                                    .font(.subheadline.weight(.semibold))
                                Text(workout.date, format: .dateTime.weekday(.wide).month().day().hour().minute())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if workout.isFinished {
                                if let rating = workout.rating, rating > 0 {
                                    HStack(spacing: 2) {
                                        ForEach(1...rating, id: \.self) { _ in
                                            Image(systemName: "star.fill")
                                                .imageScale(.small)
                                        }
                                    }
                                    .foregroundStyle(.yellow)
                                }
                            }
                        }

                        // Quick stats
                        HStack(spacing: 0) {
                            workoutStatPill(
                                icon: "figure.strengthtraining.functional",
                                value: "\(workout.exercises.count)",
                                label: "Exercises",
                                color: .accentColor
                            )
                            Divider().frame(height: 44)
                            workoutStatPill(
                                icon: "repeat",
                                value: "\(workout.exercises.flatMap(\.sets).filter { !$0.isWarmUp }.count)",
                                label: "Sets",
                                color: .purple
                            )
                            Divider().frame(height: 44)
                            workoutStatPill(
                                icon: "clock",
                                value: workout.isFinished ? (workout.formattedDuration ?? "-") : elapsedTime,
                                label: "Duration",
                                color: .orange
                            )
                        }
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 3)
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(workout.isFinished ? "Workout completed, duration \(workout.formattedDuration ?? "")" : "Workout in progress, elapsed \(elapsedTime)")

                    if !workout.isFinished {
                        Button {
                            showingFinishSheet = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Finish Workout")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [Color.green, Color(red: 0.1, green: 0.72, blue: 0.35)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: .green.opacity(0.35), radius: 10, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                    }
                }
            }

            Section {
                NavigationLink {
                    WorkoutNotesView(workout: workout)
                } label: {
                    if workout.notes.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "note.text")
                                .foregroundStyle(.secondary)
                            Text("Add notes...")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }
                    } else {
                        Text(LocalizedStringKey(workout.notes))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
            } header: {
                Text("Notes")
            }

            if workout.exercises.isEmpty {
                ContentUnavailableView {
                    Label("No Exercises", systemImage: "figure.run")
                } description: {
                    Text("Add an exercise below to get started.")
                }
                .listRowBackground(Color.clear)
            }

            Section {
                ForEach(sortedExercises) { exercise in
                    NavigationLink(value: exercise) {
                        HStack(spacing: 12) {
                            if exercise.supersetGroup != nil {
                                supersetIndicator(for: exercise)
                            }
                            // Exercise icon
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.accentColor.opacity(0.12))
                                    .frame(width: 36, height: 36)
                                Image(systemName: exercise.category?.icon ?? "figure.strengthtraining.functional")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.accentColor)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(exercise.name)
                                        .font(.subheadline.weight(.semibold))
                                    if exercise.supersetGroup != nil {
                                        Text("SS")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(Color.accentColor)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Color.accentColor.opacity(0.12), in: .capsule)
                                    }
                                }
                                HStack(spacing: 8) {
                                    if !exercise.sets.isEmpty {
                                        let workingSets = exercise.sets.filter { !$0.isWarmUp }
                                        let warmUps = exercise.sets.filter(\.isWarmUp)
                                        Text("\(workingSets.count) sets")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if !warmUps.isEmpty {
                                            Text("+ \(warmUps.count) warm-up")
                                                .font(.caption)
                                                .foregroundStyle(.orange)
                                        }
                                        if let avgRPE = averageRPE(for: exercise) {
                                            Text("RPE \(String(format: "%.0f", avgRPE))")
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(.purple)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 2)
                                                .background(.purple.opacity(0.12), in: .capsule)
                                        }
                                    }
                                    if let category = exercise.category {
                                        Text(category.rawValue)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                if !exercise.notes.isEmpty {
                                    Text(exercise.notes)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()
                        }
                        .padding(.vertical, 2)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(exerciseAccessibilityLabel(exercise))
                    }
                    .swipeActions(edge: .leading) {
                        if exercise.supersetGroup != nil {
                            Button {
                                unlinkSuperset(exercise)
                            } label: {
                                Label("Unlink", systemImage: "link.badge.plus")
                            }
                            .tint(.orange)
                        } else {
                            Button {
                                linkingSupersetFor = exercise
                            } label: {
                                Label("Superset", systemImage: "link")
                            }
                            .tint(.purple)
                        }
                    }
                }
                .onDelete { offsets in
                    let sorted = sortedExercises
                    if let index = offsets.first {
                        exerciseToDelete = sorted[index]
                    }
                }
                .onMove(perform: moveExercises)
            } header: {
                if !workout.exercises.isEmpty {
                    SectionHeader(title: "Exercises", icon: "dumbbell.fill", color: .accentColor)
                }
            }

            Section {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.12))
                            .frame(width: 36, height: 36)
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                    }
                    TextField("Exercise name", text: $newExerciseName)
                        .onChange(of: newExerciseName) {
                            showingSuggestions = !newExerciseName.isEmpty && !suggestions.isEmpty
                            autoSelectCategory()
                        }
                    Button {
                        addExercise()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .disabled(newExerciseName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityLabel("Add exercise")
                    .accessibilityHint("Adds the exercise to this workout")
                }

                Picker("Muscle Group", selection: $newExerciseCategory) {
                    ForEach(MuscleGroup.allCases) { group in
                        Label(group.rawValue, systemImage: group.icon).tag(group)
                    }
                }

                if showingSuggestions {
                    ForEach(suggestions.prefix(5), id: \.self) { suggestion in
                        Button {
                            newExerciseName = suggestion
                            showingSuggestions = false
                            autoSelectCategory()
                            addExercise()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
                                Text(suggestion)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(Color.accentColor)
                                    .font(.subheadline)
                            }
                        }
                    }
                }
            } header: {
                SectionHeader(title: "Add Exercise", icon: "plus.circle.fill", color: .accentColor)
            }
        }
        .navigationTitle(workout.name)
        .navigationDestination(for: Exercise.self) { exercise in
            ExerciseDetailView(exercise: exercise)
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showWorkoutTimer = true
                } label: {
                    Image(systemName: "stopwatch")
                }
                .accessibilityLabel("Workout Timers")

                Menu {
                    Button {
                        showingEditWorkout = true
                    } label: {
                        Label("Edit Workout", systemImage: "pencil")
                    }
                    Button {
                        saveAsTemplate()
                    } label: {
                        Label("Save as Template", systemImage: "doc.on.doc")
                    }
                    Button {
                        duplicateWorkout()
                    } label: {
                        Label("Duplicate Workout", systemImage: "plus.square.on.square")
                    }
                    Button {
                        shareItems = [formatWorkoutSummary()]
                        showingShare = true
                    } label: {
                        Label("Share as Text", systemImage: "text.quote")
                    }
                    Button {
                        let card = WorkoutShareCardView(workout: workout, weightUnit: weightUnit)
                        if let image = card.renderImage() {
                            shareItems = [image]
                            showingShare = true
                        }
                    } label: {
                        Label("Share as Image", systemImage: "photo")
                    }

                    Divider()

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete Workout", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditWorkout) {
            EditWorkoutSheet(workout: workout)
        }
        .sheet(isPresented: $showWorkoutTimer) {
            NavigationStack {
                WorkoutTimerView()
            }
        }
        .sheet(isPresented: $showingFinishSheet) {
            stopDurationTimer()
            if workout.isFinished {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                if settings.focusModeReminder {
                    showFocusEndReminder = true
                }
            }
        } content: {
            FinishWorkoutSheet(workout: workout)
        }
        .sheet(isPresented: $showingShare) {
            ShareSheet(items: shareItems)
        }
        .alert("Template Saved", isPresented: $showTemplateSaved) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\"\(workout.name)\" has been saved as a template. You can use it when creating new workouts.")
        }
        .alert("Delete Exercise?", isPresented: Binding(
            get: { exerciseToDelete != nil },
            set: { if !$0 { exerciseToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let exercise = exerciseToDelete {
                    modelContext.delete(exercise)
                    exerciseToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { exerciseToDelete = nil }
        } message: {
            if let exercise = exerciseToDelete {
                Text("Are you sure you want to delete \"\(exercise.name)\" and all its sets?")
            }
        }
        .confirmationDialog("Delete Workout?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete \"\(workout.name)\"", role: .destructive) {
                modelContext.delete(workout)
                dismiss()
            }
        } message: {
            Text("This will permanently delete this workout and all its data. This cannot be undone.")
        }
        .alert("Enable Focus Mode?", isPresented: $showFocusPrompt) {
            Button("Open Settings") {
                if let url = URL(string: "App-prefs:FOCUS") {
                    UIApplication.shared.open(url)
                }
            }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("Enable your Fitness Focus to silence notifications during your workout.")
        }
        .alert("Workout Complete!", isPresented: $showFocusEndReminder) {
            Button("Open Settings") {
                if let url = URL(string: "App-prefs:FOCUS") {
                    UIApplication.shared.open(url)
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Don't forget to turn off your Fitness Focus mode now that your workout is done.")
        }
        .sheet(item: $linkingSupersetFor) { sourceExercise in
            supersetPickerSheet(for: sourceExercise)
        }
        .onAppear {
            updateElapsedTime()
            startDurationTimer()
            startLiveActivityIfNeeded()
            if settings.focusModeReminder && !workout.isFinished && !workout.isTemplate {
                showFocusPrompt = true
            }
        }
        .onDisappear {
            stopDurationTimer()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && !workout.isFinished && !workout.isTemplate {
                updateElapsedTime()
                if durationTimer == nil {
                    startDurationTimer()
                }
            }
        }
    }

    private func averageRPE(for exercise: Exercise) -> Double? {
        let rpes = exercise.sets.filter { !$0.isWarmUp }.compactMap(\.rpe)
        guard !rpes.isEmpty else { return nil }
        return Double(rpes.reduce(0, +)) / Double(rpes.count)
    }

    private func exerciseAccessibilityLabel(_ exercise: Exercise) -> String {
        var parts = [exercise.name]
        let workingSets = exercise.sets.filter { !$0.isWarmUp }
        let warmUps = exercise.sets.filter(\.isWarmUp)
        if !workingSets.isEmpty {
            parts.append("\(workingSets.count) working sets")
        }
        if !warmUps.isEmpty {
            parts.append("\(warmUps.count) warm-up sets")
        }
        if exercise.supersetGroup != nil {
            parts.append("superset")
        }
        return parts.joined(separator: ", ")
    }

    private func setsSummary(_ sets: [ExerciseSet]) -> String {
        let workingSets = sets.filter { !$0.isWarmUp }
        let warmUpCount = sets.filter(\.isWarmUp).count
        var parts = workingSets.map { s in
            if s.isCardio {
                return [s.formattedDistance(unit: weightUnit.distanceUnit), s.formattedDuration].compactMap { $0 }.joined(separator: " in ")
            }
            return "\(s.reps)x\(weightUnit.formatShort(s.weight))"
        }
        if warmUpCount > 0 {
            parts.append("+\(warmUpCount)W")
        }
        return parts.joined(separator: "  ")
    }

    private var sortedExercises: [Exercise] {
        workout.exercises.sorted { $0.order < $1.order }
    }

    private func addExercise() {
        let name = newExerciseName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let exercise = Exercise(name: name, workout: workout, category: newExerciseCategory)
        exercise.order = (workout.exercises.map(\.order).max() ?? -1) + 1
        modelContext.insert(exercise)
        workout.exercises.append(exercise)
        newExerciseName = ""
        newExerciseCategory = .other
        showingSuggestions = false
    }

    private func workoutStatPill(icon: String, value: String, label: String, color: Color = .accentColor) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func autoSelectCategory() {
        // Auto-select category from previous usage of same exercise name
        let trimmed = newExerciseName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if let previous = allExercises.first(where: { $0.name == trimmed && $0.category != nil }) {
            newExerciseCategory = previous.category!
        }
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        var sorted = sortedExercises
        sorted.move(fromOffsets: source, toOffset: destination)
        for (index, exercise) in sorted.enumerated() {
            exercise.order = index
        }
    }

    private func formatWorkoutSummary() -> String {
        var lines: [String] = []
        lines.append("💪 \(workout.name)")

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        lines.append(dateFormatter.string(from: workout.date))

        if let duration = workout.formattedDuration {
            lines.append("Duration: \(duration)")
        }
        if let rating = workout.rating, rating > 0 {
            lines.append("Rating: \(String(repeating: "⭐", count: rating))")
        }
        lines.append("")

        let sorted = workout.exercises.sorted { $0.order < $1.order }
        for exercise in sorted {
            let workingSets = exercise.sets.filter { !$0.isWarmUp }
            let warmUps = exercise.sets.filter(\.isWarmUp)

            var header = exercise.name
            if let cat = exercise.category {
                header += " (\(cat.rawValue))"
            }
            lines.append(header)

            if !warmUps.isEmpty {
                let warmUpStr = warmUps.map { "\($0.reps)×\(weightUnit.formatShort($0.weight))" }.joined(separator: ", ")
                lines.append("  Warm-up: \(warmUpStr)")
            }
            for (i, s) in workingSets.enumerated() {
                if s.isCardio {
                    let detail = [s.formattedDistance(unit: weightUnit.distanceUnit), s.formattedDuration].compactMap { $0 }.joined(separator: " in ")
                    lines.append("  Entry \(i + 1): \(detail)")
                } else {
                    lines.append("  Set \(i + 1): \(s.reps) reps × \(weightUnit.format(s.weight))")
                }
            }
            lines.append("")
        }

        if !workout.notes.isEmpty {
            lines.append("Notes: \(workout.notes)")
            lines.append("")
        }

        lines.append("Logged with Metricly")
        return lines.joined(separator: "\n")
    }

    private func saveAsTemplate() {
        let template = Workout(name: workout.name, isTemplate: true)
        modelContext.insert(template)
        let sorted = workout.exercises.sorted { $0.order < $1.order }
        for (index, exercise) in sorted.enumerated() {
            let templateExercise = Exercise(name: exercise.name, workout: template, category: exercise.category)
            templateExercise.order = index
            templateExercise.notes = exercise.notes
            templateExercise.supersetGroup = exercise.supersetGroup
            templateExercise.customRestDuration = exercise.customRestDuration
            modelContext.insert(templateExercise)
            template.exercises.append(templateExercise)
        }
        showTemplateSaved = true
    }

    private func duplicateWorkout() {
        let newWorkout = Workout(name: workout.name, date: .now)
        modelContext.insert(newWorkout)
        let sorted = workout.exercises.sorted { $0.order < $1.order }
        for (index, exercise) in sorted.enumerated() {
            let newExercise = Exercise(name: exercise.name, workout: newWorkout, category: exercise.category)
            newExercise.order = index
            newExercise.notes = exercise.notes
            newExercise.supersetGroup = exercise.supersetGroup
            newExercise.customRestDuration = exercise.customRestDuration
            modelContext.insert(newExercise)
            newWorkout.exercises.append(newExercise)
        }
        HapticsManager.success()
    }

    private func deleteExercises(at offsets: IndexSet) {
        let sorted = sortedExercises
        for index in offsets {
            modelContext.delete(sorted[index])
        }
    }

    // MARK: - Live Activity

    private func startLiveActivityIfNeeded() {
        guard !workout.isFinished, !workout.isTemplate else { return }
        let manager = WorkoutActivityManager.shared
        if !manager.isActive {
            manager.startActivity(workoutName: workout.name)
        }
        updateLiveActivity()
    }

    private func updateLiveActivity() {
        let manager = WorkoutActivityManager.shared
        let totalSets = workout.exercises.reduce(0) { $0 + $1.sets.count }
        let currentExercise = sortedExercises.last?.name ?? workout.name
        manager.updateActivity(
            exerciseCount: workout.exercises.count,
            setCount: totalSets,
            currentExercise: currentExercise
        )
    }

    // MARK: - Duration Timer

    private func startDurationTimer() {
        guard !workout.isFinished, !workout.isTemplate else { return }
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            updateElapsedTime()
        }
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }

    private func updateElapsedTime() {
        if let duration = workout.formattedDuration {
            elapsedTime = duration
        }
    }

    // MARK: - Supersets

    private var nextSupersetGroup: Int {
        let existing = workout.exercises.compactMap(\.supersetGroup)
        return (existing.max() ?? 0) + 1
    }

    private func supersetIndicator(for exercise: Exercise) -> some View {
        let color = supersetColor(for: exercise.supersetGroup ?? 0)
        return Rectangle()
            .fill(color)
            .frame(width: 4)
            .clipShape(.rect(cornerRadius: 2))
            .padding(.trailing, 10)
            .padding(.vertical, -4)
    }

    private func supersetColor(for group: Int) -> Color {
        let colors: [Color] = [.purple, .blue, .cyan, .indigo, .pink]
        return colors[(group - 1) % colors.count]
    }

    private func unlinkSuperset(_ exercise: Exercise) {
        exercise.supersetGroup = nil
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func linkSuperset(_ exercise: Exercise, with partner: Exercise) {
        let group: Int
        if let existingGroup = partner.supersetGroup {
            group = existingGroup
        } else {
            group = nextSupersetGroup
            partner.supersetGroup = group
        }
        exercise.supersetGroup = group
        // Place them adjacent in order
        let partnerOrder = partner.order
        exercise.order = partnerOrder + 1
        // Shift exercises after them
        for ex in sortedExercises where ex.persistentModelID != exercise.persistentModelID && ex.order > partnerOrder {
            ex.order += 1
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func supersetPickerSheet(for sourceExercise: Exercise) -> some View {
        NavigationStack {
            List {
                Section {
                    Text("Choose an exercise to superset with \"\(sourceExercise.name)\".")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Section {
                    ForEach(sortedExercises.filter { $0.persistentModelID != sourceExercise.persistentModelID }) { partner in
                        Button {
                            linkSuperset(sourceExercise, with: partner)
                            linkingSupersetFor = nil
                        } label: {
                            HStack {
                                Image(systemName: "figure.strengthtraining.functional")
                                    .foregroundStyle(.tint)
                                Text(partner.name)
                                if partner.supersetGroup != nil {
                                    Spacer()
                                    Text("SS")
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(.tint.opacity(0.2), in: .capsule)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Exercises")
                }
            }
            .navigationTitle("Link Superset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { linkingSupersetFor = nil }
                }
            }
        }
    }
}
