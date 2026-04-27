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
                    activeProgramHeroCard(active)
                }

                if !programs.isEmpty {
                    allProgramsCard
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
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
                Button { showingNewProgram = true } label: {
                    Label("New Program", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewProgram) {
            NewProgramSheet()
        }
    }

    // MARK: - Active Program Hero

    private func activeProgramHeroCard(_ program: TrainingProgram) -> some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Color.accentColor, Color.accentColor.opacity(0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(.white.opacity(0.07))
                .frame(width: 200)
                .offset(x: 160, y: -60)

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.20))
                            .frame(width: 52, height: 52)
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Active Program")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.75))
                        Text(program.name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(program.formattedProgress)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                        Spacer()
                        if let todayWorkout = todayProgramDay(program) {
                            Text("Today: \(todayWorkout.workoutName)")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        } else {
                            Text("Rest day")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.65))
                        }
                    }

                    GradientProgressBar(value: program.progress, color: .white, height: 6)
                        .opacity(0.85)
                }

                Button {
                    if program.currentWeek < program.totalWeeks {
                        program.currentWeek += 1
                    }
                } label: {
                    Text("Advance to Week \(program.currentWeek + 1)")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(.white, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(program.currentWeek >= program.totalWeeks)
                .opacity(program.currentWeek >= program.totalWeeks ? 0.5 : 1)
            }
            .padding(20)
        }
        .heroCard()
    }

    // MARK: - All Programs Card

    private var allProgramsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "All Programs", icon: "calendar.badge.clock", color: .accentColor)

            VStack(spacing: 0) {
                ForEach(Array(programs.enumerated()), id: \.element.id) { idx, program in
                    NavigationLink(value: program) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(program.isActive ? Color.accentColor.gradient : AnyShapeStyle(Color(.systemGray5).gradient))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "dumbbell.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(program.isActive ? .white : .secondary)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 8) {
                                    Text(program.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    if program.isActive {
                                        Text("Active")
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 7).padding(.vertical, 2)
                                            .background(Color.accentColor.opacity(0.15), in: Capsule())
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                                Text("\(program.totalWeeks) weeks · \(program.days.count) days/week")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if program.isActive {
                                Text(program.formattedProgress)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    if idx < programs.count - 1 {
                        Divider().padding(.leading, 70)
                    }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    private func todayProgramDay(_ program: TrainingProgram) -> ProgramDay? {
        let weekday = Calendar.current.component(.weekday, from: .now)
        return program.days.first { $0.dayOfWeek == weekday }
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
            Section {
                HStack { Text("Duration"); Spacer(); Text("\(program.totalWeeks) weeks").foregroundStyle(.secondary) }
                HStack { Text("Progress"); Spacer(); Text(program.formattedProgress).foregroundStyle(.secondary) }
                Stepper("Current Week: \(program.currentWeek)", value: Binding(
                    get: { program.currentWeek },
                    set: { program.currentWeek = $0 }
                ), in: 1...program.totalWeeks)
                Toggle("Active", isOn: Binding(
                    get: { program.isActive },
                    set: { program.isActive = $0 }
                ))
            } header: { Text("Program Info") }

            Section {
                ForEach(sortedDays) { day in
                    NavigationLink(value: day) {
                        HStack {
                            Text(day.fullDayName)
                                .font(.subheadline.bold())
                                .frame(width: 90, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(day.workoutName).font(.subheadline)
                                Text("\(day.exercises.count) exercises").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteDays)

                Button { showingAddDay = true } label: {
                    Label("Add Training Day", systemImage: "plus.circle")
                }
            } header: { Text("Weekly Schedule") }
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
            Form {
                Picker("Day", selection: $selectedDay) {
                    let names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
                    ForEach(1...7, id: \.self) { day in Text(names[day - 1]).tag(day) }
                }
                TextField("Workout Name (e.g. Push, Pull, Legs)", text: $workoutName)
            }
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
                        Image(systemName: exercise.category?.icon ?? "dumbbell").foregroundStyle(.tint).frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exercise.name).font(.subheadline.bold())
                            Text("\(exercise.targetSets) sets × \(exercise.targetReps) reps")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let category = exercise.category {
                            Text(category.rawValue)
                                .font(.caption2)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color(.systemFill), in: .capsule)
                        }
                    }
                }
                .onDelete(perform: deleteExercises)
                .onMove(perform: moveExercises)
            } header: {
                if !sortedExercises.isEmpty { Text("Exercises") }
            }

            Section {
                TextField("Exercise name", text: $newName)
                Stepper("Sets: \(newSets)", value: $newSets, in: 1...10)
                HStack {
                    Text("Target Reps"); Spacer()
                    TextField("e.g. 8-12", text: $newReps)
                        .multilineTextAlignment(.trailing).frame(width: 80)
                }
                Picker("Muscle Group", selection: $newCategory) {
                    ForEach(MuscleGroup.allCases) { group in
                        Label(group.rawValue, systemImage: group.icon).tag(group)
                    }
                }
                Button { addExercise() } label: {
                    Label("Add Exercise", systemImage: "plus.circle.fill")
                }
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            } header: { Text("Add Exercise") }
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
