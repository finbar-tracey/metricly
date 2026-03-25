import SwiftUI
import SwiftData

struct TrainingProgramsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrainingProgram.startDate, order: .reverse)
    private var programs: [TrainingProgram]
    @State private var showingNewProgram = false

    var body: some View {
        List {
            if let active = programs.first(where: { $0.isActive }) {
                Section {
                    activeProgramCard(active)
                } header: {
                    Text("Active Program")
                }
            }

            Section {
                ForEach(programs) { program in
                    NavigationLink(value: program) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(program.name)
                                        .font(.headline)
                                    if program.isActive {
                                        Text("Active")
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.green.opacity(0.2), in: .capsule)
                                            .foregroundStyle(.green)
                                    }
                                }
                                Text("\(program.totalWeeks) weeks \u{00B7} \(program.days.count) days/week")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if program.isActive {
                                Text(program.formattedProgress)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete(perform: deletePrograms)
            } header: {
                Text("All Programs")
            }
        }
        .overlay {
            if programs.isEmpty {
                ContentUnavailableView {
                    Label("No Programs", systemImage: "calendar.badge.clock")
                } description: {
                    Text("Create a training program to structure your workouts across multiple weeks.")
                }
            }
        }
        .navigationTitle("Training Programs")
        .navigationDestination(for: TrainingProgram.self) { program in
            ProgramDetailView(program: program)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingNewProgram = true
                } label: {
                    Label("New Program", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewProgram) {
            NewProgramSheet()
        }
    }

    private func activeProgramCard(_ program: TrainingProgram) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.title2)
                    .foregroundStyle(.tint)
                Text(program.name)
                    .font(.title3.bold())
                Spacer()
            }

            ProgressView(value: program.progress)
                .tint(.accentColor)

            HStack {
                Text(program.formattedProgress)
                    .font(.caption)
                Spacer()
                if let todayWorkout = todayProgramDay(program) {
                    Text("Today: \(todayWorkout.workoutName)")
                        .font(.caption.bold())
                        .foregroundStyle(.tint)
                } else {
                    Text("Rest day")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                if program.currentWeek < program.totalWeeks {
                    program.currentWeek += 1
                }
            } label: {
                Text("Advance Week")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(program.currentWeek >= program.totalWeeks)
        }
        .padding(.vertical, 4)
    }

    private func todayProgramDay(_ program: TrainingProgram) -> ProgramDay? {
        let weekday = Calendar.current.component(.weekday, from: .now)
        return program.days.first { $0.dayOfWeek == weekday }
    }

    private func deletePrograms(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(programs[index])
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
            Form {
                Section {
                    TextField("Program Name", text: $name)
                    Stepper("Duration: \(weeks) weeks", value: $weeks, in: 1...52)
                } header: {
                    Text("Details")
                } footer: {
                    Text("You can add training days and exercises after creating the program.")
                }
            }
            .navigationTitle("New Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
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

    private var sortedDays: [ProgramDay] {
        program.days.sorted { $0.dayOfWeek < $1.dayOfWeek }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Duration")
                    Spacer()
                    Text("\(program.totalWeeks) weeks")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Progress")
                    Spacer()
                    Text(program.formattedProgress)
                        .foregroundStyle(.secondary)
                }
                Stepper("Current Week: \(program.currentWeek)", value: Binding(
                    get: { program.currentWeek },
                    set: { program.currentWeek = $0 }
                ), in: 1...program.totalWeeks)
                Toggle("Active", isOn: Binding(
                    get: { program.isActive },
                    set: { program.isActive = $0 }
                ))
            } header: {
                Text("Program Info")
            }

            Section {
                ForEach(sortedDays) { day in
                    NavigationLink(value: day) {
                        HStack {
                            Text(day.fullDayName)
                                .font(.subheadline.bold())
                                .frame(width: 90, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(day.workoutName)
                                    .font(.subheadline)
                                Text("\(day.exercises.count) exercises")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteDays)

                Button {
                    showingAddDay = true
                } label: {
                    Label("Add Training Day", systemImage: "plus.circle")
                }
            } header: {
                Text("Weekly Schedule")
            }
        }
        .navigationTitle(program.name)
        .navigationDestination(for: ProgramDay.self) { day in
            ProgramDayDetailView(day: day)
        }
        .sheet(isPresented: $showingAddDay) {
            AddProgramDaySheet(program: program)
        }
    }

    private func deleteDays(at offsets: IndexSet) {
        let sorted = sortedDays
        for index in offsets {
            modelContext.delete(sorted[index])
        }
    }
}

struct AddProgramDaySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let program: TrainingProgram
    @State private var selectedDay = 2 // Monday
    @State private var workoutName = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("Day", selection: $selectedDay) {
                    let names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
                    ForEach(1...7, id: \.self) { day in
                        Text(names[day - 1]).tag(day)
                    }
                }
                TextField("Workout Name (e.g. Push, Pull, Legs)", text: $workoutName)
            }
            .navigationTitle("Add Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
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

    private var sortedExercises: [ProgramExercise] {
        day.exercises.sorted { $0.order < $1.order }
    }

    var body: some View {
        List {
            if sortedExercises.isEmpty {
                ContentUnavailableView {
                    Label("No Exercises", systemImage: "figure.run")
                } description: {
                    Text("Add exercises to this training day.")
                }
                .listRowBackground(Color.clear)
            }

            Section {
                ForEach(sortedExercises) { exercise in
                    HStack {
                        Image(systemName: exercise.category?.icon ?? "dumbbell")
                            .foregroundStyle(.tint)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exercise.name)
                                .font(.subheadline.bold())
                            Text("\(exercise.targetSets) sets \u{00D7} \(exercise.targetReps) reps")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let category = exercise.category {
                            Text(category.rawValue)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.systemFill), in: .capsule)
                        }
                    }
                }
                .onDelete(perform: deleteExercises)
                .onMove(perform: moveExercises)
            } header: {
                if !sortedExercises.isEmpty {
                    Text("Exercises")
                }
            }

            Section {
                TextField("Exercise name", text: $newName)
                Stepper("Sets: \(newSets)", value: $newSets, in: 1...10)
                HStack {
                    Text("Target Reps")
                    Spacer()
                    TextField("e.g. 8-12", text: $newReps)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
                Picker("Muscle Group", selection: $newCategory) {
                    ForEach(MuscleGroup.allCases) { group in
                        Label(group.rawValue, systemImage: group.icon).tag(group)
                    }
                }
                Button {
                    addExercise()
                } label: {
                    Label("Add Exercise", systemImage: "plus.circle.fill")
                }
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            } header: {
                Text("Add Exercise")
            }
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
        newName = ""
        newSets = 3
        newReps = "8-12"
        newCategory = .other
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
