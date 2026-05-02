import SwiftUI
import SwiftData

struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Workout> { !$0.isTemplate }) private var workouts: [Workout]
    @Environment(\.weightUnit) private var weightUnit
    @State private var searchText = ""
    @State private var cachedExercises: [ExerciseInfo] = []

    // Rebuild only when workouts change, not on every keystroke
    private func buildAllExercises() -> [ExerciseInfo] {
        var seen: [String: ExerciseInfo] = [:]
        for guide in ExerciseGuide.database {
            let key = guide.name.lowercased()
            seen[key] = ExerciseInfo(name: guide.name, category: guide.category,
                bestWeight: 0, totalSets: 0, sessionCount: 0, lastUsed: .distantPast)
        }
        for workout in workouts {
            for exercise in workout.exercises {
                let key = exercise.name.lowercased()
                let workingSets = exercise.sets.filter { !$0.isWarmUp }
                let bestWeight = workingSets.map(\.weight).max() ?? 0
                let totalSets = workingSets.count
                if var existing = seen[key] {
                    existing.sessionCount += 1
                    existing.totalSets += totalSets
                    if bestWeight > existing.bestWeight { existing.bestWeight = bestWeight }
                    if exercise.category != nil { existing.category = exercise.category }
                    if let date = exercise.workout?.date, date > existing.lastUsed { existing.lastUsed = date }
                    seen[key] = existing
                } else {
                    seen[key] = ExerciseInfo(name: exercise.name, category: exercise.category,
                        bestWeight: bestWeight, totalSets: totalSets, sessionCount: 1,
                        lastUsed: exercise.workout?.date ?? .distantPast)
                }
            }
        }
        return seen.values.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    private var filteredExercises: [ExerciseInfo] {
        if searchText.isEmpty { return cachedExercises }
        let query = searchText.lowercased()
        return cachedExercises.filter { $0.name.lowercased().contains(query) }
    }

    private var groupedExercises: [(MuscleGroup, [ExerciseInfo])] {
        let grouped = Dictionary(grouping: filteredExercises) { $0.category ?? .other }
        return grouped.sorted { $0.key.rawValue < $1.key.rawValue }
    }

    var body: some View {
        List {
            if filteredExercises.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ForEach(groupedExercises, id: \.0) { group, exercises in
                    Section {
                        ForEach(exercises) { exercise in
                            NavigationLink(value: exercise.name) {
                                exerciseRow(exercise, group: group)
                            }
                            .contextMenu {
                                Menu {
                                    ForEach(MuscleGroup.allCases) { newGroup in
                                        Button {
                                            updateCategory(exerciseName: exercise.name, to: newGroup)
                                        } label: {
                                            HStack {
                                                Label(newGroup.rawValue, systemImage: newGroup.icon)
                                                if exercise.category == newGroup {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    Label("Change Category", systemImage: "folder")
                                }
                            }
                        }
                    } header: {
                        HStack(spacing: 6) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(groupColor(group).gradient)
                                    .frame(width: 18, height: 18)
                                MuscleIconView(group: group, color: .white)
                                    .frame(width: 11, height: 11)
                            }
                            Text(group.rawValue)
                                .textCase(nil)
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search exercises")
        .navigationTitle("Exercise Library")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { cachedExercises = buildAllExercises() }
        .onChange(of: workouts.count) { cachedExercises = buildAllExercises() }
    }

    private func exerciseRow(_ exercise: ExerciseInfo, group: MuscleGroup) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(groupColor(group).opacity(0.12))
                    .frame(width: 34, height: 34)
                MuscleIconView(group: group, color: groupColor(group))
                    .frame(width: 18, height: 18)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(exercise.name).font(.subheadline.weight(.medium))
                    if ExerciseGuide.find(exercise.name) != nil {
                        Image(systemName: "text.book.closed")
                            .font(.caption2)
                            .foregroundStyle(Color.accentColor)
                    }
                }
                if exercise.sessionCount > 0 {
                    HStack(spacing: 4) {
                        Text("\(exercise.sessionCount) sessions")
                        Text("·").foregroundStyle(.tertiary)
                        Text("\(exercise.totalSets) sets")
                        if exercise.bestWeight > 0 {
                            Text("·").foregroundStyle(.tertiary)
                            Text("Best: \(weightUnit.formatShort(exercise.bestWeight))")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                } else {
                    Text("No history yet")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            if exercise.sessionCount > 0 {
                Text(exercise.lastUsed, format: .dateTime.month(.abbreviated).day())
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(exercise.name), \(exercise.sessionCount) sessions")
    }

    private func groupColor(_ group: MuscleGroup) -> Color {
        switch group {
        case .chest: return .blue
        case .back: return .indigo
        case .shoulders: return .purple
        case .biceps: return .orange
        case .triceps: return .red
        case .legs: return .green
        case .core: return .teal
        case .cardio: return .pink
        case .other: return .gray
        }
    }

    private func updateCategory(exerciseName: String, to newCategory: MuscleGroup) {
        for workout in workouts {
            for exercise in workout.exercises where exercise.name.lowercased() == exerciseName.lowercased() {
                exercise.category = newCategory
            }
        }
        modelContext.saveOrLog()
        HapticsManager.lightTap()
    }
}

struct ExerciseInfo: Identifiable {
    let id = UUID()
    let name: String
    var category: MuscleGroup?
    var bestWeight: Double
    var totalSets: Int
    var sessionCount: Int
    var lastUsed: Date
}
