import SwiftUI
import SwiftData

struct LiftGoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.weightUnit) private var weightUnit
    @Query private var goals: [LiftGoal]
    @Query(filter: #Predicate<Workout> { !$0.isTemplate }) private var workouts: [Workout]
    @State private var showingAddGoal = false
    @State private var newExerciseName = ""
    @State private var newTargetWeight = ""
    @FocusState private var isWeightFocused: Bool

    private var activeGoals: [LiftGoal] {
        goals.filter { $0.achievedDate == nil }.sorted { $0.exerciseName < $1.exerciseName }
    }

    private var completedGoals: [LiftGoal] {
        goals.filter { $0.achievedDate != nil }.sorted { ($0.achievedDate ?? .distantPast) > ($1.achievedDate ?? .distantPast) }
    }

    private var exerciseNames: [String] {
        let names = Set(workouts.flatMap { $0.exercises.map(\.name) })
        return names.sorted()
    }

    private func currentPR(for exerciseName: String) -> Double {
        workouts
            .flatMap(\.exercises)
            .filter { $0.name.lowercased() == exerciseName.lowercased() }
            .flatMap(\.sets)
            .filter { !$0.isWarmUp }
            .map(\.weight)
            .max() ?? 0
    }

    var body: some View {
        List {
            if goals.isEmpty && !showingAddGoal {
                ContentUnavailableView {
                    Label("No Lift Goals", systemImage: "target")
                } description: {
                    Text("Set a weight target for an exercise and track your progress toward it.")
                } actions: {
                    Button("Add Goal") { showingAddGoal = true }
                        .buttonStyle(.borderedProminent)
                }
                .listRowBackground(Color.clear)
            }

            if showingAddGoal {
                Section {
                    Picker("Exercise", selection: $newExerciseName) {
                        Text("Select…").tag("")
                        ForEach(exerciseNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    HStack {
                        TextField("Target (\(weightUnit.label))", text: $newTargetWeight)
                            .keyboardType(.decimalPad)
                            .focused($isWeightFocused)
                        Button {
                            addGoal()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                        .disabled(newExerciseName.isEmpty || newTargetWeight.isEmpty)
                    }
                } header: {
                    Text("New Goal")
                }
            }

            if !activeGoals.isEmpty {
                Section("Active Goals") {
                    ForEach(activeGoals) { goal in
                        goalRow(goal)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            modelContext.delete(activeGoals[index])
                        }
                    }
                }
            }

            if !completedGoals.isEmpty {
                Section("Completed") {
                    ForEach(completedGoals) { goal in
                        goalRow(goal)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            modelContext.delete(completedGoals[index])
                        }
                    }
                }
            }
        }
        .navigationTitle("Lift Goals")
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isWeightFocused = false }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddGoal.toggle()
                } label: {
                    Label("Add Goal", systemImage: "plus")
                }
            }
        }
    }

    private func goalRow(_ goal: LiftGoal) -> some View {
        let pr = currentPR(for: goal.exerciseName)
        let progress = goal.targetWeight > 0 ? min(1.0, pr / goal.targetWeight) : 0
        let isComplete = goal.achievedDate != nil

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.exerciseName)
                        .font(.subheadline.weight(.semibold))
                    HStack(spacing: 4) {
                        Text("PR: \(weightUnit.format(pr))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("→")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(weightUnit.format(goal.targetWeight))
                            .font(.caption.bold())
                            .foregroundStyle(isComplete ? .green : Color.accentColor)
                    }
                }
                Spacer()
                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Text("\(Int(progress * 100))%")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(Color.accentColor)
                }
            }

            ProgressView(value: progress)
                .tint(isComplete ? .green : Color.accentColor)
        }
        .padding(.vertical, 4)
    }

    private func addGoal() {
        guard let target = Double(newTargetWeight), target > 0 else { return }
        let targetKg = weightUnit.toKg(target)
        let goal = LiftGoal(exerciseName: newExerciseName, targetWeight: targetKg)
        modelContext.insert(goal)
        newExerciseName = ""
        newTargetWeight = ""
        showingAddGoal = false
        isWeightFocused = false
    }
}

#Preview {
    NavigationStack {
        LiftGoalsView()
    }
    .modelContainer(for: [Workout.self, LiftGoal.self], inMemory: true)
}
