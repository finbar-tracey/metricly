import SwiftUI
import SwiftData

struct FullWorkoutListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Workout> { !$0.isTemplate }, sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]
    @Query private var settingsArray: [UserSettings]
    @Environment(\.weightUnit) private var weightUnit

    @State private var searchText = ""
    @State private var filterDateRange: DateRange = .all
    @State private var filterMuscleGroup: MuscleGroup? = nil
    @State private var filterRating: Int? = nil
    @State private var workoutToDelete: Workout?
    @State private var showingAddWorkout = false
    @State private var repeatConfirmation = false

    enum DateRange: String, CaseIterable {
        case all = "All Time"
        case week = "This Week"
        case month = "This Month"
        case threeMonths = "3 Months"
        case year = "This Year"
    }

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
            let cutoff = cutoffDate(for: filterDateRange)
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

    private func cutoffDate(for range: DateRange) -> Date {
        let calendar = Calendar.current
        switch range {
        case .all: return .distantPast
        case .week: return calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        case .month: return calendar.dateInterval(of: .month, for: .now)?.start ?? .now
        case .threeMonths: return calendar.date(byAdding: .month, value: -3, to: .now) ?? .now
        case .year: return calendar.date(byAdding: .year, value: -1, to: .now) ?? .now
        }
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
            // MARK: - Hero
            if !workouts.isEmpty {
                Section {
                    workoutHeroCard
                        .listRowBackground(Color.clear)
                        .listRowInsets(.init(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }

            // Filter chips
            if !workouts.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Menu {
                                ForEach(DateRange.allCases, id: \.self) { range in
                                    Button {
                                        filterDateRange = range
                                    } label: {
                                        if filterDateRange == range {
                                            Label(range.rawValue, systemImage: "checkmark")
                                        } else {
                                            Text(range.rawValue)
                                        }
                                    }
                                }
                            } label: {
                                filterChipLabel(
                                    label: filterDateRange == .all ? "Date" : filterDateRange.rawValue,
                                    isActive: filterDateRange != .all,
                                    icon: "calendar"
                                )
                            }

                            Menu {
                                Button {
                                    filterMuscleGroup = nil
                                } label: {
                                    if filterMuscleGroup == nil {
                                        Label("All", systemImage: "checkmark")
                                    } else {
                                        Text("All")
                                    }
                                }
                                ForEach(MuscleGroup.allCases) { group in
                                    Button {
                                        filterMuscleGroup = group
                                    } label: {
                                        if filterMuscleGroup == group {
                                            Label(group.rawValue, systemImage: "checkmark")
                                        } else {
                                            Text(group.rawValue)
                                        }
                                    }
                                }
                            } label: {
                                filterChipLabel(
                                    label: filterMuscleGroup?.rawValue ?? "Muscle",
                                    isActive: filterMuscleGroup != nil,
                                    icon: "figure.strengthtraining.traditional"
                                )
                            }

                            Menu {
                                Button {
                                    filterRating = nil
                                } label: {
                                    if filterRating == nil {
                                        Label("Any", systemImage: "checkmark")
                                    } else {
                                        Text("Any")
                                    }
                                }
                                ForEach(1...5, id: \.self) { stars in
                                    Button {
                                        filterRating = stars
                                    } label: {
                                        if filterRating == stars {
                                            Label(String(repeating: "★", count: stars), systemImage: "checkmark")
                                        } else {
                                            Text(String(repeating: "★", count: stars))
                                        }
                                    }
                                }
                            } label: {
                                filterChipLabel(
                                    label: filterRating.map { "\($0)★" } ?? "Rating",
                                    isActive: filterRating != nil,
                                    icon: "star"
                                )
                            }

                            if hasActiveFilters {
                                Button {
                                    filterDateRange = .all
                                    filterMuscleGroup = nil
                                    filterRating = nil
                                } label: {
                                    Text("Clear")
                                        .font(.caption.bold())
                                        .foregroundStyle(.red)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(.red.opacity(0.1), in: Capsule())
                                }
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            }

            if !filteredWorkouts.isEmpty {
                Section {
                    ForEach(filteredWorkouts) { workout in
                        NavigationLink(value: workout) {
                            WorkoutCardView(workout: workout)
                        }
                    }
                    .onDelete { offsets in
                        if let index = offsets.first {
                            workoutToDelete = filteredWorkouts[index]
                        }
                    }
                } header: {
                    HStack {
                        SectionHeader(
                            title: hasActiveFilters ? "Filtered Workouts" : "All Workouts",
                            icon: "dumbbell.fill",
                            color: .accentColor
                        )
                        if hasActiveFilters {
                            Spacer()
                            Text("\(filteredWorkouts.count)")
                                .font(.caption.bold().monospacedDigit())
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            } else if hasActiveFilters {
                ContentUnavailableView {
                    Label("No Matches", systemImage: "line.3.horizontal.decrease.circle")
                } description: {
                    Text("No workouts match your current filters.")
                } actions: {
                    Button("Clear Filters") {
                        filterDateRange = .all
                        filterMuscleGroup = nil
                        filterRating = nil
                    }
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .overlay {
            if workouts.isEmpty {
                ContentUnavailableView {
                    Label("No Workouts Yet", systemImage: "dumbbell.fill")
                } description: {
                    Text("Tap the + button to log your first workout.")
                } actions: {
                    Button {
                        showingAddWorkout = true
                    } label: {
                        Text("Start Workout")
                            .font(.subheadline.bold())
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if filteredWorkouts.isEmpty && !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .navigationTitle("All Workouts")
        .searchable(text: $searchText, prompt: "Search workouts or exercises")
        .navigationDestination(for: Workout.self) { workout in
            WorkoutDetailView(workout: workout)
        }
        .navigationDestination(for: String.self) { exerciseName in
            ExerciseHistoryView(exerciseName: exerciseName)
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

    // MARK: - Hero Card

    private var workoutHeroCard: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Color.accentColor, Color.blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle().fill(.white.opacity(0.07)).frame(width: 180).offset(x: 110, y: -30)
            Circle().fill(.white.opacity(0.05)).frame(width: 90).offset(x: -20, y: 70)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 6) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                    Text("All Workouts")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }

                HStack(spacing: 0) {
                    heroStatCol(label: "Total", value: "\(workouts.count)", icon: "dumbbell.fill")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 36)
                    heroStatCol(label: "This Week", value: "\(thisWeekCount)", icon: "calendar")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 36)
                    heroStatCol(label: "This Month", value: "\(thisMonthCount)", icon: "calendar.badge.clock")
                }
                .padding(.vertical, 10)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(18)
        }
        .frame(minHeight: 130)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.heroRadius))
    }

    private func heroStatCol(label: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 11)).foregroundStyle(.white.opacity(0.75))
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white).monospacedDigit()
            Text(label).font(.caption2.weight(.medium)).foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Filter Chip Label

    private func filterChipLabel(label: String, isActive: Bool, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(label)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isActive ? Color.accentColor : Color(.tertiarySystemFill), in: Capsule())
        .foregroundStyle(isActive ? .white : .primary)
    }

}

#Preview {
    NavigationStack {
        FullWorkoutListView()
    }
    .modelContainer(for: Workout.self, inMemory: true)
}
