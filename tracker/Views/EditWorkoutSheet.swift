import SwiftUI

struct EditWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    let workout: Workout
    @State private var name: String
    @State private var date: Date
    @State private var notes: String

    init(workout: Workout) {
        self.workout = workout
        _name = State(initialValue: workout.name)
        _date = State(initialValue: workout.date)
        _notes = State(initialValue: workout.notes)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.accentColor, Color.accentColor.opacity(0.72)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 38, height: 38)
                                .shadow(color: Color.accentColor.opacity(0.40), radius: 5, y: 2)
                            Image(systemName: "pencil")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        TextField("Workout Name", text: $name)
                            .font(.subheadline)
                    }
                    .listRowBackground(Color(.secondarySystemGroupedBackground))

                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.red, Color.red.opacity(0.72)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 38, height: 38)
                                .shadow(color: Color.red.opacity(0.40), radius: 5, y: 2)
                            Image(systemName: "calendar")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                            .font(.subheadline)
                    }
                    .listRowBackground(Color(.secondarySystemGroupedBackground))
                } header: {
                    SectionHeader(title: "Details", icon: "dumbbell.fill", color: .accentColor)
                }

                Section {
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.orange, Color.orange.opacity(0.72)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 38, height: 38)
                                .shadow(color: Color.orange.opacity(0.40), radius: 5, y: 2)
                            Image(systemName: "note.text")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        TextField("Add notes…", text: $notes, axis: .vertical)
                            .font(.subheadline)
                            .lineLimit(3...6)
                    }
                    .listRowBackground(Color(.secondarySystemGroupedBackground))
                } header: {
                    SectionHeader(title: "Notes", icon: "note.text", color: .orange)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Edit Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        workout.name = name
                        workout.date = date
                        workout.notes = notes
                        dismiss()
                    }
                    .font(.headline)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
