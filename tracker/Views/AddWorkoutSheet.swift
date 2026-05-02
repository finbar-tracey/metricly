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
                // Details section first for better flow
                Section {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(Color.accentColor.gradient)
                                .frame(width: 28, height: 28)
                            Image(systemName: "pencil")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        TextField("Workout Name", text: $name)
                    }
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(Color.red.gradient)
                                .frame(width: 28, height: 28)
                            Image(systemName: "calendar")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                    }
                } header: {
                    Text("Details")
                }

                if !templates.isEmpty {
                    Section {
                        ForEach(templates) { template in
                            let isSelected = selectedTemplate?.persistentModelID == template.persistentModelID
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedTemplate = template
                                    name = template.name
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
                                            .frame(width: 36, height: 36)
                                        Image(systemName: isSelected ? "checkmark" : "doc.text")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(isSelected ? .white : .secondary)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(template.name)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        Text("\(template.exercises.count) exercises")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.body)
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                                .padding(.vertical, isSelected ? 2 : 0)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.accentColor.opacity(isSelected ? 0.4 : 0), lineWidth: 1.5)
                                        .padding(-6)
                                )
                            }
                            .accessibilityLabel("\(template.name), \(template.exercises.count) exercises")
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
                    } header: {
                        Text("From Template")
                    }
                }

                if let template = selectedTemplate, !template.exercises.isEmpty {
                    Section {
                        ForEach(template.exercises.sorted { $0.order < $1.order }) { exercise in
                            HStack(spacing: 10) {
                                if let category = exercise.category {
                                    MuscleIconView(group: category, color: Color.accentColor)
                                        .frame(width: 16, height: 16)
                                } else {
                                    Image(systemName: "dumbbell")
                                        .font(.caption)
                                        .foregroundStyle(Color.accentColor)
                                        .frame(width: 16)
                                }
                                Text(exercise.name)
                                    .font(.subheadline)
                                Spacer()
                                if let category = exercise.category {
                                    Text(category.rawValue)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    } header: {
                        Text("Exercises Preview")
                    }
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
                        modelContext.saveOrLog()
                        HapticsManager.workoutStarted()
                        dismiss()
                    }
                    .font(.headline)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func createWorkout() {
        let workout = Workout(name: name, date: date)
        modelContext.insert(workout)
        if let template = selectedTemplate {
            workout.copyExercises(from: template.exercises, into: modelContext)
        }
    }

    private static func defaultWorkoutName() -> String {
        "Workout - \(Date.now.formatted(.dateTime.month(.abbreviated).day()))"
    }
}
