import SwiftUI

enum TrainingProgramsSections {

    static func activeProgramHeroCard(
        _ program: TrainingProgram,
        todayWorkout: ProgramDay?,
        onAdvanceWeek: @escaping () -> Void
    ) -> some View {
        HeroCard(palette: AppTheme.Gradients.calm) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial.opacity(0.7))
                            .frame(width: 56, height: 56)
                            .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.5))
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Active Program")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))
                            .tracking(0.5)
                            .textCase(.uppercase)
                        Text(program.name)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(program.formattedProgress)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.88))
                        Spacer()
                        if let todayWorkout {
                            Text("Today: \(todayWorkout.workoutName)")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(.white.opacity(0.18), in: Capsule())
                                .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 0.5))
                        } else {
                            Text("Rest day")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.78))
                        }
                    }

                    GradientProgressBar(value: program.progress, color: .white, height: 8)
                }
                .padding(14)
                .background(.ultraThinMaterial.opacity(0.55), in: RoundedRectangle(cornerRadius: AppTheme.miniCardRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.miniCardRadius, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 0.5)
                )

                Button(action: onAdvanceWeek) {
                    Text("Advance to Week \(program.currentWeek + 1)")
                        .font(.subheadline.bold())
                        .foregroundStyle(AppTheme.Signal.calm)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.white, in: Capsule())
                        .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                }
                .buttonStyle(.pressableCard)
                .disabled(program.currentWeek >= program.totalWeeks)
                .opacity(program.currentWeek >= program.totalWeeks ? 0.5 : 1)
            }
            .padding(20)
        }
    }

    static func allProgramsCard(programs: [TrainingProgram]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "All Programs", icon: "calendar.badge.clock", color: .accentColor)

            VStack(spacing: 0) {
                ForEach(Array(programs.enumerated()), id: \.element.id) { idx, program in
                    NavigationLink(value: program) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(program.isActive ? AnyShapeStyle(Color.accentColor.gradient) : AnyShapeStyle(Color(.systemGray5).gradient))
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

    static func todayProgramDay(_ program: TrainingProgram) -> ProgramDay? {
        let weekday = Calendar.current.component(.weekday, from: .now)
        return program.days.first { $0.dayOfWeek == weekday }
    }

    static func programsEmptyOverlay(onNewProgram: @escaping () -> Void) -> some View {
        EmptyStateView(
            icon: "calendar.badge.clock",
            title: "No Programs",
            subtitle: "Create a training program to structure your workouts across multiple weeks.",
            action: .init(label: "New Program", perform: onNewProgram)
        )
    }

    static func newProgramForm(name: Binding<String>, weeks: Binding<Int>) -> some View {
        Form {
            Section {
                TextField("Program Name", text: name)
                Stepper("Duration: \(weeks.wrappedValue) weeks", value: weeks, in: 1...52)
            } header: {
                Text("Details")
            } footer: {
                Text("You can add training days and exercises after creating the program.")
            }
        }
    }

    @ViewBuilder
    static func programInfoSection(
        program: TrainingProgram,
        currentWeek: Binding<Int>
    ) -> some View {
        Section {
            HStack { Text("Duration"); Spacer(); Text("\(program.totalWeeks) weeks").foregroundStyle(.secondary) }
            HStack { Text("Progress"); Spacer(); Text(program.formattedProgress).foregroundStyle(.secondary) }
            Stepper("Current Week: \(currentWeek.wrappedValue)", value: currentWeek, in: 1...program.totalWeeks)
            Toggle("Active", isOn: Binding(
                get: { program.isActive },
                set: { program.isActive = $0 }
            ))
        } header: { Text("Program Info") }
    }

    @ViewBuilder
    static func weeklyScheduleSection(
        sortedDays: [ProgramDay],
        onDelete: @escaping (IndexSet) -> Void,
        onAddDay: @escaping () -> Void
    ) -> some View {
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
            .onDelete(perform: onDelete)

            Button(action: onAddDay) {
                Label("Add Training Day", systemImage: "plus.circle")
            }
        } header: { Text("Weekly Schedule") }
    }

    static func addProgramDayForm(selectedDay: Binding<Int>, workoutName: Binding<String>) -> some View {
        Form {
            Picker("Day", selection: selectedDay) {
                let names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
                ForEach(1...7, id: \.self) { day in Text(names[day - 1]).tag(day) }
            }
            TextField("Workout Name (e.g. Push, Pull, Legs)", text: workoutName)
        }
    }

    @ViewBuilder
    static func programDayExercisesSection(
        sortedExercises: [ProgramExercise],
        onDelete: @escaping (IndexSet) -> Void,
        onMove: @escaping (IndexSet, Int) -> Void
    ) -> some View {
        if sortedExercises.isEmpty {
            EmptyStateView(
                icon: "figure.run",
                title: "No Exercises",
                subtitle: "Add exercises to this training day."
            )
            .listRowBackground(Color.clear)
        }

        Section {
            ForEach(sortedExercises) { exercise in
                HStack {
                    Group {
                        if let category = exercise.category {
                            MuscleIconView(group: category, color: Color.accentColor)
                        } else {
                            Image(systemName: "dumbbell").foregroundStyle(.tint)
                        }
                    }.frame(width: 18, height: 18)
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
            .onDelete(perform: onDelete)
            .onMove(perform: onMove)
        } header: {
            if !sortedExercises.isEmpty { Text("Exercises") }
        }
    }

    static func addProgramExerciseSection(
        newName: Binding<String>,
        newSets: Binding<Int>,
        newReps: Binding<String>,
        newCategory: Binding<MuscleGroup>,
        onAdd: @escaping () -> Void
    ) -> some View {
        Section {
            TextField("Exercise name", text: newName)
            Stepper("Sets: \(newSets.wrappedValue)", value: newSets, in: 1...10)
            HStack {
                Text("Target Reps"); Spacer()
                TextField("e.g. 8-12", text: newReps)
                    .multilineTextAlignment(.trailing).frame(width: 80)
            }
            Picker("Muscle Group", selection: newCategory) {
                ForEach(MuscleGroup.allCases) { group in
                    Label(group.rawValue, systemImage: group.icon).tag(group)
                }
            }
            Button(action: onAdd) {
                Label("Add Exercise", systemImage: "plus.circle.fill")
            }
            .disabled(newName.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)
        } header: { Text("Add Exercise") }
    }
}
