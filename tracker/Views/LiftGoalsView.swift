import SwiftUI
import SwiftData

struct LiftGoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.weightUnit) private var weightUnit
    @Query private var goals: [LiftGoal]
    @Query(filter: #Predicate<Workout> { !$0.isTemplate && $0.endTime != nil }) private var workouts: [Workout]
    @State private var showingAddGoal = false
    @State private var newExerciseName = ""
    @State private var newTargetWeight = ""
    @FocusState private var isWeightFocused: Bool
    @State private var goalToDelete: LiftGoal?

    private var activeGoals: [LiftGoal] {
        goals.filter { $0.achievedDate == nil }.sorted { $0.exerciseName < $1.exerciseName }
    }

    private var completedGoals: [LiftGoal] {
        goals.filter { $0.achievedDate != nil }.sorted { ($0.achievedDate ?? .distantPast) > ($1.achievedDate ?? .distantPast) }
    }

    private var exerciseNames: [String] {
        Array(Set(workouts.flatMap { $0.exercises.map(\.name) })).sorted()
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
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                if !goals.isEmpty { heroCard }

                if showingAddGoal { addGoalCard }

                if !activeGoals.isEmpty { activeGoalsCard }

                if !completedGoals.isEmpty { completedGoalsCard }

                if goals.isEmpty && !showingAddGoal {
                    emptyStateCard
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Lift Goals")
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isWeightFocused = false }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showingAddGoal.toggle() }
                } label: {
                    Label("Add Goal", systemImage: showingAddGoal ? "xmark" : "plus")
                }
            }
        }
        .alert("Delete Goal?", isPresented: Binding(
            get: { goalToDelete != nil },
            set: { if !$0 { goalToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let goal = goalToDelete { modelContext.delete(goal); goalToDelete = nil }
            }
            Button("Cancel", role: .cancel) { goalToDelete = nil }
        } message: {
            if let goal = goalToDelete {
                Text("Delete the goal for \"\(goal.exerciseName)\"?")
            }
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.65)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(.white.opacity(0.07)).frame(width: 200).offset(x: 160, y: -60)

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle().fill(.white.opacity(0.20)).frame(width: 52, height: 52)
                        Image(systemName: "target")
                            .font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Lift Goals")
                            .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.75))
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(activeGoals.count)")
                                .font(.system(size: 36, weight: .black, design: .rounded))
                                .foregroundStyle(.white).monospacedDigit()
                            Text("active")
                                .font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.75))
                        }
                    }
                    Spacer()
                    if !completedGoals.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill").font(.caption.bold())
                            Text("\(completedGoals.count) done").font(.caption.bold())
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.white.opacity(0.20), in: Capsule())
                        .foregroundStyle(.white)
                    }
                }

                if !activeGoals.isEmpty {
                    let overallProgress = activeGoals.map { goal -> Double in
                        let pr = currentPR(for: goal.exerciseName)
                        return goal.targetWeight > 0 ? min(1.0, pr / goal.targetWeight) : 0
                    }.reduce(0, +) / Double(activeGoals.count)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Overall Progress")
                                .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.85))
                            Spacer()
                            Text("\(Int(overallProgress * 100))%")
                                .font(.caption.bold().monospacedDigit()).foregroundStyle(.white)
                        }
                        GradientProgressBar(value: overallProgress, color: .white, height: 6).opacity(0.85)
                    }
                }
            }
            .padding(20)
        }
        .heroCard()
    }

    // MARK: - Add Goal Card

    private var addGoalCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "New Goal", icon: "plus.circle.fill", color: .accentColor)

            VStack(spacing: 0) {
                Picker("Exercise", selection: $newExerciseName) {
                    Text("Select exercise…").tag("")
                    ForEach(exerciseNames, id: \.self) { name in Text(name).tag(name) }
                }
                .padding(.horizontal, 16).padding(.vertical, 10)

                Divider().padding(.leading, 16)

                HStack(spacing: 12) {
                    TextField("Target weight (\(weightUnit.label))", text: $newTargetWeight)
                        .keyboardType(.decimalPad).focused($isWeightFocused).font(.subheadline)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 13)

                Divider().padding(.leading, 16)

                Button { addGoal() } label: {
                    Label("Add Goal", systemImage: "plus.circle.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(newExerciseName.isEmpty || newTargetWeight.isEmpty
                                    ? Color(.systemFill) : Color.accentColor.opacity(0.9))
                        .foregroundStyle(newExerciseName.isEmpty || newTargetWeight.isEmpty
                                         ? Color.secondary : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
                }
                .disabled(newExerciseName.isEmpty || newTargetWeight.isEmpty)
                .buttonStyle(.plain)
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    // MARK: - Active Goals Card

    private var activeGoalsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Active Goals", icon: "target", color: .accentColor)

            VStack(spacing: 0) {
                ForEach(Array(activeGoals.enumerated()), id: \.element.id) { idx, goal in
                    goalRow(goal)
                        .contextMenu {
                            Button(role: .destructive) { goalToDelete = goal } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    if idx < activeGoals.count - 1 { Divider().padding(.leading, 16) }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    // MARK: - Completed Goals Card

    private var completedGoalsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Completed", icon: "checkmark.circle.fill", color: .green)

            VStack(spacing: 0) {
                ForEach(Array(completedGoals.enumerated()), id: \.element.id) { idx, goal in
                    goalRow(goal)
                        .contextMenu {
                            Button(role: .destructive) { goalToDelete = goal } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    if idx < completedGoals.count - 1 { Divider().padding(.leading, 16) }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    private func goalRow(_ goal: LiftGoal) -> some View {
        let pr = currentPR(for: goal.exerciseName)
        let progress = goal.targetWeight > 0 ? min(1.0, pr / goal.targetWeight) : 0
        let isComplete = goal.achievedDate != nil
        let rowColor: Color = isComplete ? .green : .accentColor

        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(rowColor.opacity(0.12)).frame(width: 40, height: 40)
                Image(systemName: isComplete ? "checkmark.circle.fill" : "target")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(rowColor)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(goal.exerciseName).font(.subheadline.weight(.semibold))
                    Spacer()
                    if isComplete {
                        Text("Done").font(.caption.bold())
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Color.green.opacity(0.15), in: Capsule())
                            .foregroundStyle(.green)
                    } else {
                        Text("\(Int(progress * 100))%")
                            .font(.caption.bold().monospacedDigit()).foregroundStyle(rowColor)
                    }
                }
                GradientProgressBar(value: progress, color: rowColor, height: 5)
                HStack(spacing: 4) {
                    Text("PR: \(weightUnit.format(pr))")
                    Text("→").foregroundStyle(.tertiary)
                    Text(weightUnit.format(goal.targetWeight)).fontWeight(.semibold).foregroundStyle(rowColor)
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Empty State

    private var emptyStateCard: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.12)).frame(width: 70, height: 70)
                Image(systemName: "target")
                    .font(.system(size: 28, weight: .semibold)).foregroundStyle(Color.accentColor)
            }
            VStack(spacing: 6) {
                Text("No Lift Goals").font(.headline)
                Text("Set a weight target for an exercise and track your progress.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showingAddGoal = true }
            } label: {
                Text("Add Your First Goal")
                    .font(.subheadline.bold()).padding(.horizontal, 24).padding(.vertical, 12)
                    .background(Color.accentColor.gradient)
                    .foregroundStyle(.white).clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
        .appCard()
    }

    // MARK: - Actions

    private func addGoal() {
        guard let target = Double(newTargetWeight), target > 0 else { return }
        let targetKg = weightUnit.toKg(target)
        let goal = LiftGoal(exerciseName: newExerciseName, targetWeight: targetKg)
        modelContext.insert(goal)
        newExerciseName = ""; newTargetWeight = ""
        withAnimation { showingAddGoal = false }
        isWeightFocused = false
    }
}

#Preview {
    NavigationStack { LiftGoalsView() }
        .modelContainer(for: [Workout.self, LiftGoal.self], inMemory: true)
}
