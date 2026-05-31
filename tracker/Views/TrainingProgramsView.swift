import SwiftUI
import SwiftData

struct TrainingProgramsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrainingProgram.startDate, order: .reverse)
    private var programs: [TrainingProgram]
    @State private var showingNewProgram = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                if let active = programs.first(where: { $0.isActive }) {
                    TrainingProgramsSections.activeProgramHeroCard(
                        active,
                        todayWorkout: TrainingProgramsSections.todayProgramDay(active),
                        onAdvanceWeek: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            if active.currentWeek < active.totalWeeks {
                                active.currentWeek += 1
                            }
                        }
                    )
                }

                if !programs.isEmpty {
                    TrainingProgramsSections.allProgramsCard(programs: programs)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .overlay {
            if programs.isEmpty {
                TrainingProgramsSections.programsEmptyOverlay { showingNewProgram = true }
            }
        }
        .navigationTitle("Training Programs")
        .navigationDestination(for: TrainingProgram.self) { program in
            ProgramDetailView(program: program)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingNewProgram = true } label: {
                    Label("New Program", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewProgram) {
            NewProgramSheet()
        }
    }
}

struct NewProgramSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var weeks = 4

    var body: some View {
        NavigationStack {
            TrainingProgramsSections.newProgramForm(name: $name, weeks: $weeks)
                .navigationTitle("New Program")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Create") {
                            let program = TrainingProgram(name: name, totalWeeks: weeks)
                            modelContext.insert(program)
                            dismiss()
                        }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
        }
    }
}

struct ProgramDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let program: TrainingProgram
    @State private var showingAddDay = false

    private var sortedDays: [ProgramDay] { program.days.sorted { $0.dayOfWeek < $1.dayOfWeek } }

    var body: some View {
        List {
            TrainingProgramsSections.programInfoSection(
                program: program,
                currentWeek: Binding(
                    get: { program.currentWeek },
                    set: { program.currentWeek = $0 }
                )
            )
            TrainingProgramsSections.weeklyScheduleSection(
                sortedDays: sortedDays,
                onDelete: deleteDays,
                onAddDay: { showingAddDay = true }
            )
        }
        .navigationTitle(program.name)
        .navigationDestination(for: ProgramDay.self) { day in ProgramDayDetailView(day: day) }
        .sheet(isPresented: $showingAddDay) { AddProgramDaySheet(program: program) }
    }

    private func deleteDays(at offsets: IndexSet) {
        let sorted = sortedDays
        for index in offsets { modelContext.delete(sorted[index]) }
    }
}

struct AddProgramDaySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let program: TrainingProgram
    @State private var selectedDay = 2
    @State private var workoutName = ""

    var body: some View {
        NavigationStack {
            TrainingProgramsSections.addProgramDayForm(
                selectedDay: $selectedDay,
                workoutName: $workoutName
            )
            .navigationTitle("Add Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let day = ProgramDay(dayOfWeek: selectedDay, workoutName: workoutName, program: program)
                        day.order = program.days.count
                        modelContext.insert(day)
                        program.days.append(day)
                        dismiss()
                    }
                    .disabled(workoutName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct ProgramDayDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let day: ProgramDay
    @State private var newName = ""
    @State private var newSets = 3
    @State private var newReps = "8-12"
    @State private var newCategory: MuscleGroup = .other

    private var sortedExercises: [ProgramExercise] { day.exercises.sorted { $0.order < $1.order } }

    var body: some View {
        List {
            TrainingProgramsSections.programDayExercisesSection(
                sortedExercises: sortedExercises,
                onDelete: deleteExercises,
                onMove: moveExercises
            )
            TrainingProgramsSections.addProgramExerciseSection(
                newName: $newName,
                newSets: $newSets,
                newReps: $newReps,
                newCategory: $newCategory,
                onAdd: addExercise
            )
        }
        .navigationTitle("\(day.fullDayName) — \(day.workoutName)")
    }

    private func addExercise() {
        let exercise = ProgramExercise(
            name: newName.trimmingCharacters(in: .whitespaces),
            targetSets: newSets,
            targetReps: newReps,
            category: newCategory
        )
        exercise.order = day.exercises.count
        exercise.day = day
        modelContext.insert(exercise)
        day.exercises.append(exercise)
        newName = ""; newSets = 3; newReps = "8-12"; newCategory = .other
    }

    private func deleteExercises(at offsets: IndexSet) {
        let sorted = sortedExercises
        for index in offsets { modelContext.delete(sorted[index]) }
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        var sorted = sortedExercises
        sorted.move(fromOffsets: source, toOffset: destination)
        for (index, exercise) in sorted.enumerated() { exercise.order = index }
    }
}
