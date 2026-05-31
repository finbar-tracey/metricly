import SwiftUI
import SwiftData

struct FullWorkoutListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Workout> { !$0.isTemplate }, sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]
    @Query private var settingsArray: [UserSettings]
    @Environment(\.weightUnit) private var weightUnit

    @State private var searchText = ""
    @State private var filterDateRange: FullWorkoutListSections.DateRange = .all
    @State private var filterMuscleGroup: MuscleGroup? = nil
    @State private var filterRating: Int? = nil
    @State private var workoutToDelete: Workout?
    @State private var showingAddWorkout = false
    @State private var repeatConfirmation = false

    private var hasActiveFilters: Bool {
        filterDateRange != .all || filterMuscleGroup != nil || filterRating != nil
    }

    private var filteredWorkouts: [Workout] {
        var result = workouts

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { workout in
                workout.name.lowercased().contains(query)
                || workout.exercises.contains { $0.name.lowercased().contains(query) }
            }
        }

        if filterDateRange != .all {
            let cutoff = FullWorkoutListSections.cutoffDate(for: filterDateRange)
            result = result.filter { $0.date >= cutoff }
        }

        if let group = filterMuscleGroup {
            result = result.filter { $0.exercises.contains { $0.category == group } }
        }

        if let rating = filterRating {
            result = result.filter { $0.rating == rating }
        }

        return result
    }

    private var thisWeekCount: Int {
        let start = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        return workouts.filter { $0.date >= start }.count
    }

    private var thisMonthCount: Int {
        let start = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
        return workouts.filter { $0.date >= start }.count
    }

    var body: some View {
        List {
            if !workouts.isEmpty {
                FullWorkoutListSections.heroSection(
                    total: workouts.count,
                    thisWeek: thisWeekCount,
                    thisMonth: thisMonthCount
                )
                FullWorkoutListSections.filterChipsSection(
                    filterDateRange: $filterDateRange,
                    filterMuscleGroup: $filterMuscleGroup,
                    filterRating: $filterRating,
                    hasActiveFilters: hasActiveFilters,
                    onClearFilters: clearFilters
                )
            }

            if !filteredWorkouts.isEmpty {
                FullWorkoutListSections.workoutListSection(
                    workouts: filteredWorkouts,
                    hasActiveFilters: hasActiveFilters,
                    onDelete: { offsets in
                        if let index = offsets.first {
                            workoutToDelete = filteredWorkouts[index]
                        }
                    }
                )
            } else if hasActiveFilters {
                FullWorkoutListSections.noFilterMatchesRow(onClearFilters: clearFilters)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .overlay {
            if workouts.isEmpty {
                FullWorkoutListSections.emptyLibraryOverlay { showingAddWorkout = true }
            } else if filteredWorkouts.isEmpty && !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .navigationTitle("All Workouts")
        .searchable(text: $searchText, prompt: "Search workouts or exercises")
        .navigationDestination(for: Workout.self) { workout in
            WorkoutDetailView(workout: workout)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddWorkout = true
                } label: {
                    Label("Add Workout", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddWorkout) {
            AddWorkoutSheet()
                .environment(\.weightUnit, weightUnit)
        }
        .confirmationDialog("Delete Workout?", isPresented: Binding(
            get: { workoutToDelete != nil },
            set: { if !$0 { workoutToDelete = nil } }
        )) {
            if let workout = workoutToDelete {
                Button("Delete \"\(workout.name)\"", role: .destructive) {
                    modelContext.delete(workout)
                    workoutToDelete = nil
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }

    private func clearFilters() {
        filterDateRange = .all
        filterMuscleGroup = nil
        filterRating = nil
    }
}

#Preview {
    NavigationStack {
        FullWorkoutListView()
    }
    .modelContainer(for: Workout.self, inMemory: true)
}
