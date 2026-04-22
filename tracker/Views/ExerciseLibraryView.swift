import SwiftUI
import SwiftData

struct ExerciseLibraryView: View {
    @Query(filter: #Predicate<Workout> { !$0.isTemplate }) private var workouts: [Workout]
    @Environment(\.weightUnit) private var weightUnit
    @State private var searchText = ""

    private var allExercises: [ExerciseInfo] {
        var seen: [String: ExerciseInfo] = [:]

        // Seed with built-in exercise guide database
        for guide in ExerciseGuide.database {
            let key = guide.name.lowercased()
            seen[key] = ExerciseInfo(
                name: guide.name,
                category: guide.category,
                bestWeight: 0,
                totalSets: 0,
                sessionCount: 0,
                lastUsed: .distantPast
            )
        }

        // Overlay with actual workout data
        for workout in workouts {
            for exercise in workout.exercises {
                let key = exercise.name.lowercased()
                let workingSets = exercise.sets.filter { !$0.isWarmUp }
                let bestWeight = workingSets.map(\.weight).max() ?? 0
                let totalSets = workingSets.count

                if var existing = seen[key] {
                    existing.sessionCount += 1
                    existing.totalSets += totalSets
                    if bestWeight > existing.bestWeight {
                        existing.bestWeight = bestWeight
                    }
                    if exercise.category != nil {
                        existing.category = exercise.category
                    }
                    if let date = exercise.workout?.date, date > existing.lastUsed {
                        existing.lastUsed = date
                    }
                    seen[key] = existing
                } else {
                    seen[key] = ExerciseInfo(
                        name: exercise.name,
                        category: exercise.category,
                        bestWeight: bestWeight,
                        totalSets: totalSets,
                        sessionCount: 1,
                        lastUsed: exercise.workout?.date ?? .distantPast
                    )
                }
            }
        }

        return seen.values.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    private var filteredExercises: [ExerciseInfo] {
        if searchText.isEmpty { return allExercises }
        let query = searchText.lowercased()
        return allExercises.filter { $0.name.lowercased().contains(query) }
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
                                exerciseRow(exercise)
                            }
                        }
                    } header: {
                        Label(group.rawValue, systemImage: group.icon)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search exercises")
        .navigationTitle("Exercise Library")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: String.self) { name in
            ExerciseHistoryView(exerciseName: name)
        }
    }

    private func exerciseRow(_ exercise: ExerciseInfo) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(exercise.name)
                        .font(.headline)
                    if ExerciseGuide.find(exercise.name) != nil {
                        Image(systemName: "text.book.closed")
                            .font(.caption2)
                            .foregroundStyle(.tint)
                    }
                }
                if exercise.sessionCount > 0 {
                    HStack(spacing: 8) {
                        Text("\(exercise.sessionCount) sessions")
                        Text("·")
                        Text("\(exercise.totalSets) sets")
                        if exercise.bestWeight > 0 {
                            Text("·")
                            Text("Best: \(weightUnit.formatShort(exercise.bestWeight))")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    Text("No history yet")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            if exercise.sessionCount > 0 {
                Text(exercise.lastUsed, format: .dateTime.month(.abbreviated).day())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(exercise.name), \(exercise.sessionCount) sessions, best \(weightUnit.format(exercise.bestWeight))")
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
