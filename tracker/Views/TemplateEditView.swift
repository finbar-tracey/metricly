import SwiftUI
import SwiftData

struct TemplateEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allExercises: [Exercise]
    let template: Workout
    @State private var editingName = false
    @State private var newName = ""
    @State private var newExerciseName = ""
    @State private var newExerciseCategory: MuscleGroup = .other
    @State private var showingSuggestions = false

    private var suggestions: [String] {
        let history = Set(allExercises.map(\.name))
        let current = Set(template.exercises.map(\.name))
        let available = history.subtracting(current)
        if newExerciseName.isEmpty {
            return available.sorted()
        }
        return available.filter {
            $0.localizedCaseInsensitiveContains(newExerciseName)
        }.sorted()
    }

    private var sortedExercises: [Exercise] {
        template.exercises.sorted { $0.order < $1.order }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text(template.name)
                        .font(.headline)
                    Spacer()
                    Button("Rename") {
                        newName = template.name
                        editingName = true
                    }
                    .font(.subheadline)
                }
            } header: {
                Text("Template Name")
            }

            Section {
                if template.exercises.isEmpty {
                    Text("No exercises yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedExercises) { exercise in
                        HStack {
                            Image(systemName: exercise.category?.icon ?? "dumbbell")
                                .foregroundStyle(.tint)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.name)
                                    .font(.subheadline.weight(.medium))
                                if let category = exercise.category {
                                    Text(category.rawValue)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                if !exercise.notes.isEmpty {
                                    Text(exercise.notes)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteExercises)
                    .onMove(perform: moveExercises)
                }
            } header: {
                Text("Exercises")
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
        .navigationTitle("Edit Template")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .alert("Rename Template", isPresented: $editingName) {
            TextField("Name", text: $newName)
            Button("Save") {
                template.name = newName
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func addExercise() {
        let name = newExerciseName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let exercise = Exercise(name: name, workout: template, category: newExerciseCategory)
        exercise.order = (template.exercises.map(\.order).max() ?? -1) + 1
        modelContext.insert(exercise)
        template.exercises.append(exercise)
        newExerciseName = ""
        newExerciseCategory = .other
        showingSuggestions = false
    }

    private func autoSelectCategory() {
        let trimmed = newExerciseName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if let previous = allExercises.first(where: { $0.name == trimmed && $0.category != nil }) {
            newExerciseCategory = previous.category!
        }
    }

    private func deleteExercises(at offsets: IndexSet) {
        let sorted = sortedExercises
        for index in offsets {
            modelContext.delete(sorted[index])
        }
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        var sorted = sortedExercises
        sorted.move(fromOffsets: source, toOffset: destination)
        for (index, exercise) in sorted.enumerated() {
            exercise.order = index
        }
    }
}
