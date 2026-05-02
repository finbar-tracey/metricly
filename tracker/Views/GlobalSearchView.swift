import SwiftUI
import SwiftData

struct GlobalSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.weightUnit) private var weightUnit
    @Query(filter: #Predicate<Workout> { !$0.isTemplate }, sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]
    @Query(sort: \CardioSession.date, order: .reverse) private var cardioSessions: [CardioSession]
    @Query private var settingsArray: [UserSettings]

    @State private var query: String = ""
    @FocusState private var focused: Bool

    // Flat list of all unique exercise names ever performed
    private var allExerciseNames: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for workout in workouts {
            for exercise in workout.exercises {
                let key = exercise.name.lowercased()
                if !seen.contains(key) {
                    seen.insert(key)
                    result.append(exercise.name)
                }
            }
        }
        return result.sorted()
    }

    // MARK: - Filtered results

    private var trimmed: String { query.trimmingCharacters(in: .whitespaces) }
    private var isSearching: Bool { !trimmed.isEmpty }

    private var matchedWorkouts: [Workout] {
        guard isSearching else { return [] }
        let q = trimmed.lowercased()
        return workouts.filter { $0.name.lowercased().contains(q) }
    }

    private var matchedExercises: [String] {
        guard isSearching else { return [] }
        let q = trimmed.lowercased()
        return allExerciseNames.filter { $0.lowercased().contains(q) }
    }

    private var matchedCardio: [CardioSession] {
        guard isSearching else { return [] }
        let q = trimmed.lowercased()
        return cardioSessions.filter {
            $0.title.lowercased().contains(q) ||
            $0.cardioType.lowercased().contains(q)
        }
    }

    private var hasResults: Bool {
        !matchedWorkouts.isEmpty || !matchedExercises.isEmpty || !matchedCardio.isEmpty
    }

    private var useKm: Bool { settingsArray.first?.useKilograms ?? true }
    private var distanceUnit: DistanceUnit { useKm ? .km : .mi }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if !isSearching {
                    emptyPrompt
                } else if !hasResults {
                    noResultsView
                } else {
                    resultsList
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Workouts, exercises, runs…")
            .autocorrectionDisabled()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear { focused = true }
    }

    // MARK: - Empty state

    private var emptyPrompt: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.quaternary)
            Text("Search everything")
                .font(.title3.weight(.semibold))
            Text("Workouts, exercises, runs, and cardio sessions")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            Spacer()
        }
    }

    private var noResultsView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.quaternary)
            Text("No results for \"\(trimmed)\"")
                .font(.headline)
            Text("Try a different search term")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Spacer()
        }
    }

    // MARK: - Results list

    private var resultsList: some View {
        List {
            if !matchedWorkouts.isEmpty {
                Section("Workouts (\(matchedWorkouts.count))") {
                    ForEach(matchedWorkouts) { workout in
                        NavigationLink(value: workout) {
                            workoutRow(workout)
                        }
                    }
                }
            }

            if !matchedExercises.isEmpty {
                Section("Exercises (\(matchedExercises.count))") {
                    ForEach(matchedExercises, id: \.self) { name in
                        NavigationLink(value: name) {
                            exerciseRow(name)
                        }
                    }
                }
            }

            if !matchedCardio.isEmpty {
                Section("Cardio (\(matchedCardio.count))") {
                    ForEach(matchedCardio) { session in
                        NavigationLink {
                            CardioSessionDetailView(session: session)
                        } label: {
                            cardioRow(session)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationDestination(for: Workout.self) { workout in
            WorkoutDetailView(workout: workout)
        }
        .navigationDestination(for: String.self) { name in
            ExerciseHistoryView(exerciseName: name)
        }
    }

    // MARK: - Row helpers

    private func workoutRow(_ workout: Workout) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Text(workout.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let dur = workout.formattedDuration {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(dur)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func exerciseRow(_ name: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.purple.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "figure.strengthtraining.functional")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.purple)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                let count = workouts.filter { $0.exercises.contains { $0.name.lowercased() == name.lowercased() } }.count
                Text("\(count) workout\(count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func cardioRow(_ session: CardioSession) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: CardioType(rawValue: session.cardioType)?.icon ?? "figure.run")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.orange)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title.isEmpty ? (CardioType(rawValue: session.cardioType)?.shortName ?? "Cardio") : session.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Text(session.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if session.distanceMeters > 0 {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        let km = session.distanceMeters / 1000
                        Text(String(format: "%.2f %@", distanceUnit.display(km), distanceUnit.label))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
