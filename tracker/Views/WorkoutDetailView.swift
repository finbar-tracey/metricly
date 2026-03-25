import SwiftUI
import SwiftData
import UIKit

struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.weightUnit) private var weightUnit
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
                    HStack {
                        Image(systemName: workout.isFinished ? "checkmark.circle.fill" : "timer")
                            .foregroundStyle(workout.isFinished ? .green : Color.accentColor)
                        if workout.isFinished {
                            Text("Completed")
                                .font(.subheadline.bold())
                            if let rating = workout.rating, rating > 0 {
                                HStack(spacing: 2) {
                                    ForEach(1...rating, id: \.self) { _ in
                                        Image(systemName: "star.fill")
                                            .imageScale(.small)
                                    }
                                }
                                .foregroundStyle(.yellow)
                            }
                            Spacer()
                            if let duration = workout.formattedDuration {
                                Text(duration)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("In Progress")
                                .font(.subheadline.bold())
                            Spacer()
                            Text(elapsedTime)
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(workout.isFinished ? "Workout completed, duration \(workout.formattedDuration ?? "")" : "Workout in progress, elapsed \(elapsedTime)")
                    if !workout.isFinished {
                        Button {
                            showingFinishSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Finish Workout")
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }

            if !workout.notes.isEmpty {
                Section {
                    Text(workout.notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Notes")
                }
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
                        HStack(spacing: 0) {
                            if exercise.supersetGroup != nil {
                                supersetIndicator(for: exercise)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: exercise.category?.icon ?? "figure.strengthtraining.functional")
                                        .foregroundStyle(.tint)
                                    Text(exercise.name)
                                        .font(.headline)
                                    if let category = exercise.category {
                                        Text(category.rawValue)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color(.systemFill), in: .capsule)
                                    }
                                    if exercise.supersetGroup != nil {
                                        Text("SS")
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(.tint.opacity(0.2), in: .capsule)
                                    }
                                }
                                if !exercise.sets.isEmpty {
                                    Text(setsSummary(exercise.sets))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if !exercise.notes.isEmpty {
                                    Text(exercise.notes)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.vertical, 2)
                        }
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
                    Text("Exercises")
                }
            }

            Section {
                HStack {
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
                            Label(suggestion, systemImage: "clock.arrow.circlepath")
                                .foregroundStyle(.primary)
                        }
                    }
                }
            } header: {
                Text("Add Exercise")
            }
        }
        .navigationTitle(workout.name)
        .navigationDestination(for: Exercise.self) { exercise in
            ExerciseDetailView(exercise: exercise)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
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
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditWorkout) {
            EditWorkoutSheet(workout: workout)
        }
        .sheet(isPresented: $showingFinishSheet) {
            stopDurationTimer()
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
        .sheet(item: $linkingSupersetFor) { sourceExercise in
            supersetPickerSheet(for: sourceExercise)
        }
        .onAppear {
            updateElapsedTime()
            startDurationTimer()
            startLiveActivityIfNeeded()
        }
        .onDisappear {
            stopDurationTimer()
        }
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
            "\(s.reps)x\(weightUnit.formatShort(s.weight))"
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
                lines.append("  Set \(i + 1): \(s.reps) reps × \(weightUnit.format(s.weight))")
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
