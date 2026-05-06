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
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.accentColor, Color.accentColor.opacity(0.72)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 32, height: 32)
                                .shadow(color: Color.accentColor.opacity(0.40), radius: 4, y: 2)
                            Image(systemName: "pencil")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        TextField("Workout Name", text: $name)
                    }
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.red, Color.red.opacity(0.72)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 32, height: 32)
                                .shadow(color: Color.red.opacity(0.40), radius: 4, y: 2)
                            Image(systemName: "calendar")
                                .font(.system(size: 14, weight: .bold))
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
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(
                                                isSelected
                                                    ? AnyShapeStyle(
                                                        LinearGradient(
                                                            colors: [Color.accentColor, Color.accentColor.opacity(0.72)],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                    )
                                                    : AnyShapeStyle(Color(.tertiarySystemFill))
                                            )
                                            .frame(width: 40, height: 40)
                                            .shadow(
                                                color: isSelected ? Color.accentColor.opacity(0.40) : .clear,
                                                radius: 6, y: 2
                                            )
                                        Image(systemName: isSelected ? "checkmark" : "doc.text")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(isSelected ? .white : .secondary)
                                    }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(template.name)
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.primary)
                                        Text("\(template.exercises.count) exercises")
                                            .font(.caption.weight(.semibold))
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
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
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
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.accentColor.opacity(0.16))
                                        .frame(width: 30, height: 30)
                                    if let category = exercise.category {
                                        MuscleIconView(group: category, color: Color.accentColor)
                                            .frame(width: 14, height: 14)
                                    } else {
                                        Image(systemName: "dumbbell")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                                Text(exercise.name)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                Spacer()
                                if let category = exercise.category {
                                    Text(category.rawValue.uppercased())
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .tracking(0.4)
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
