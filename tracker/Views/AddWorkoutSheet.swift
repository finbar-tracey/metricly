import SwiftUI
import SwiftData

struct AddWorkoutSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Workout> { $0.isTemplate }, sort: \Workout.name)
    private var templates: [Workout]
    @State private var name = defaultWorkoutName()
    @State private var date = Date.now
    @State private var selectedTemplate: Workout?

    var body: some View {
        NavigationStack {
            Form {
                if !templates.isEmpty {
                    Section {
                        ForEach(templates) { template in
                            Button {
                                selectedTemplate = template
                                name = template.name
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(template.name)
                                            .foregroundStyle(.primary)
                                        Text(template.exercises.map(\.name).joined(separator: ", "))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if selectedTemplate?.persistentModelID == template.persistentModelID {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.tint)
                                            .accessibilityHidden(true)
                                    }
                                }
                            }
                            .accessibilityLabel("\(template.name), \(template.exercises.map(\.name).joined(separator: ", "))")
                            .accessibilityAddTraits(selectedTemplate?.persistentModelID == template.persistentModelID ? .isSelected : [])
                        }
                    } header: {
                        Text("From Template")
                    }
                }

                if let template = selectedTemplate, !template.exercises.isEmpty {
                    Section {
                        ForEach(template.exercises.sorted { $0.order < $1.order }) { exercise in
                            HStack {
                                Image(systemName: exercise.category?.icon ?? "dumbbell")
                                    .foregroundStyle(.tint)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name)
                                        .font(.subheadline)
                                    if let category = exercise.category {
                                        Text(category.rawValue)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Template Preview")
                    }
                }

                Section {
                    TextField("Workout Name", text: $name)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                } header: {
                    Text("Details")
                }
            }
            .navigationTitle("New Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        createWorkout()
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func createWorkout() {
        let workout = Workout(name: name, date: date)
        modelContext.insert(workout)

        if let template = selectedTemplate {
            let sorted = template.exercises.sorted { $0.order < $1.order }
            for (index, templateExercise) in sorted.enumerated() {
                let exercise = Exercise(name: templateExercise.name, workout: workout, category: templateExercise.category)
                exercise.order = index
                exercise.notes = templateExercise.notes
                exercise.supersetGroup = templateExercise.supersetGroup
                exercise.customRestDuration = templateExercise.customRestDuration
                modelContext.insert(exercise)
                workout.exercises.append(exercise)
            }
        }
    }

    private static func defaultWorkoutName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "Workout - \(formatter.string(from: .now))"
    }
}
