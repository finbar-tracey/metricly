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
            // MARK: - Name
            Section {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.purple.opacity(0.12))
                            .frame(width: 36, height: 36)
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.purple)
                    }
                    Text(template.name)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button("Rename") {
                        newName = template.name
                        editingName = true
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.1), in: .capsule)
                }
                .padding(.vertical, 4)
                .listRowBackground(Color(.secondarySystemGroupedBackground))
            } header: {
                SectionHeader(title: "Template Name", icon: "doc.on.doc.fill", color: .purple)
            }

            // MARK: - Exercises
            Section {
                if template.exercises.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.tertiary)
                        Text("No exercises yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(sortedExercises) { exercise in
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.accentColor.opacity(0.12))
                                    .frame(width: 36, height: 36)
                                if let category = exercise.category {
                                    MuscleIconView(group: category, color: Color.accentColor)
                                        .frame(width: 16, height: 16)
                                } else {
                                    Image(systemName: "dumbbell.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(exercise.name)
                                    .font(.subheadline.weight(.semibold))
                                if let category = exercise.category {
                                    Text(category.rawValue)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
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
                        .padding(.vertical, 4)
                        .listRowBackground(Color(.secondarySystemGroupedBackground))
                    }
                    .onDelete(perform: deleteExercises)
                    .onMove(perform: moveExercises)
                }
            } header: {
                SectionHeader(
                    title: "Exercises (\(template.exercises.count))",
                    icon: "dumbbell.fill",
                    color: .accentColor
                )
            }

            // MARK: - Add Exercise
            Section {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green.opacity(0.12))
                            .frame(width: 32, height: 32)
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.green)
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
                            .foregroundStyle(.green)
                    }
                    .disabled(newExerciseName.trimmingCharacters(in: .whitespaces).isEmpty)
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
                            autoSelectCategory()
                            addExercise()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
                                Text(suggestion).foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(.green)
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
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Edit Template")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .alert("Rename Template", isPresented: $editingName) {
            TextField("Name", text: $newName)
            Button("Save") { template.name = newName }
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
