import SwiftUI
import SwiftData

/// Notes, empty state, exercise rows, and add-exercise row for workout detail.
struct WorkoutDetailExerciseListSection: View {
    let workout: Workout
    let weightUnit: WeightUnit
    let allExercises: [Exercise]
    let sortedExercises: [Exercise]
    let suggestions: [String]
    @Binding var newExerciseName: String
    @Binding var newExerciseCategory: MuscleGroup
    @Binding var showingSuggestions: Bool
    @Binding var exerciseToDelete: Exercise?
    @Binding var linkingSupersetFor: Exercise?
    let onAddExercise: () -> Void
    let onAutoSelectCategory: () -> Void
    let onMoveExercises: (IndexSet, Int) -> Void
    let onUnlinkSuperset: (Exercise) -> Void

    var body: some View {
        Section {
            NavigationLink {
                WorkoutNotesView(workout: workout)
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.12))
                            .frame(width: 32, height: 32)
                        Image(systemName: "note.text")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.blue)
                    }
                    if workout.notes.isEmpty {
                        Text("Add notes…")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    } else {
                        Text(LocalizedStringKey(workout.notes))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))
        } header: {
            SectionHeader(title: "Notes", icon: "note.text", color: .blue)
        }

        if workout.exercises.isEmpty {
            Section {
                VStack(spacing: 14) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 38))
                        .foregroundStyle(.tertiary)
                    Text("No Exercises Yet")
                        .font(.subheadline.weight(.semibold))
                    Text("Add an exercise below to get started.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .listRowBackground(Color.clear)
            }
        }

        if !workout.exercises.isEmpty {
            Section {
                ForEach(sortedExercises) { exercise in
                    NavigationLink(value: exercise) {
                        WorkoutExerciseRow(
                            exercise: exercise,
                            weightUnit: weightUnit,
                            averageRPE: averageRPE(for: exercise),
                            badge: WorkoutDetailProgress.progressBadge(
                                for: exercise,
                                allExercises: allExercises,
                                weightUnit: weightUnit
                            )
                        )
                    }
                    .listRowBackground(Color(.secondarySystemGroupedBackground))
                    .swipeActions(edge: .leading) {
                        if exercise.supersetGroup != nil {
                            Button {
                                onUnlinkSuperset(exercise)
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
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(exerciseAccessibilityLabel(exercise))
                }
                .onDelete { offsets in
                    if let index = offsets.first {
                        exerciseToDelete = sortedExercises[index]
                    }
                }
                .onMove(perform: onMoveExercises)
            } header: {
                SectionHeader(
                    title: "Exercises (\(workout.exercises.count))",
                    icon: "dumbbell.fill",
                    color: .accentColor
                )
            }
        }

        Section {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }
                TextField("Exercise name", text: $newExerciseName)
                    .onChange(of: newExerciseName) {
                        showingSuggestions = !newExerciseName.isEmpty && !suggestions.isEmpty
                        onAutoSelectCategory()
                    }
                Button {
                    onAddExercise()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }
                .disabled(newExerciseName.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Add exercise")
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            Picker("Muscle Group", selection: $newExerciseCategory) {
                ForEach(MuscleGroup.allCases) { group in
                    Label(group.rawValue, systemImage: group.icon).tag(group)
                }
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            if showingSuggestions {
                ForEach(suggestions.prefix(5), id: \.self) { suggestion in
                    Button {
                        newExerciseName = suggestion
                        showingSuggestions = false
                        onAutoSelectCategory()
                        onAddExercise()
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
                    .listRowBackground(Color(.secondarySystemGroupedBackground))
                }
            }
        } header: {
            SectionHeader(title: "Add Exercise", icon: "plus.circle.fill", color: .green)
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
        if !workingSets.isEmpty { parts.append("\(workingSets.count) working sets") }
        if !warmUps.isEmpty { parts.append("\(warmUps.count) warm-up sets") }
        if exercise.supersetGroup != nil { parts.append("superset") }
        return parts.joined(separator: ", ")
    }

    static func sortedExercises(in workout: Workout) -> [Exercise] {
        workout.exercises.sorted { $0.order < $1.order }
    }

    static func moveExercises(in workout: Workout, from source: IndexSet, to destination: Int) {
        var sorted = sortedExercises(in: workout)
        sorted.move(fromOffsets: source, toOffset: destination)
        for (index, exercise) in sorted.enumerated() {
            exercise.order = index
        }
    }

    static func unlinkSuperset(_ exercise: Exercise) {
        exercise.supersetGroup = nil
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func linkSuperset(
        _ exercise: Exercise,
        with partner: Exercise,
        in workout: Workout
    ) {
        let sorted = sortedExercises(in: workout)
        let group: Int
        if let existingGroup = partner.supersetGroup {
            group = existingGroup
        } else {
            group = nextSupersetGroup(in: workout)
            partner.supersetGroup = group
        }
        exercise.supersetGroup = group
        let partnerOrder = partner.order
        exercise.order = partnerOrder + 1
        for ex in sorted where ex.persistentModelID != exercise.persistentModelID && ex.order > partnerOrder {
            ex.order += 1
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private static func nextSupersetGroup(in workout: Workout) -> Int {
        let existing = workout.exercises.compactMap(\.supersetGroup)
        return (existing.max() ?? 0) + 1
    }
}
