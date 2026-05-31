import SwiftUI
import SwiftData

struct ActivityLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appServices) private var appServices
    @Environment(\.weightUnit) private var weightUnit
    @Query(sort: \ManualActivity.date, order: .reverse) private var activities: [ManualActivity]

    @State private var showingAddSheet = false
    @State private var externalWorkouts: [ExternalWorkout] = []
    @State private var isLoadingExternal = true
    @State private var selectedType: ManualActivity.ActivityType = .walk

    private var todayActivities: [ManualActivity] {
        let start = Calendar.current.startOfDay(for: .now)
        return activities.filter { $0.date >= start }
    }

    private var todayExternalWorkouts: [ExternalWorkout] {
        let start = Calendar.current.startOfDay(for: .now)
        return externalWorkouts.filter { $0.startDate >= start && !$0.isFromThisApp }
    }

    private var todayMinutes: Int {
        todayActivities.reduce(0) { $0 + $1.durationMinutes }
        + todayExternalWorkouts.reduce(0) { $0 + Int($1.duration / 60) }
    }

    private var thisWeekActivities: [ManualActivity] {
        guard let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start else { return [] }
        return activities.filter { $0.date >= weekStart }
    }

    private var thisWeekExternalWorkouts: [ExternalWorkout] {
        guard let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start else { return [] }
        return externalWorkouts.filter { $0.startDate >= weekStart && !$0.isFromThisApp }
    }

    private var thisWeekMinutes: Int {
        thisWeekActivities.reduce(0) { $0 + $1.durationMinutes }
        + thisWeekExternalWorkouts.reduce(0) { $0 + Int($1.duration / 60) }
    }

    private var thisWeekTotalCount: Int {
        thisWeekActivities.count + thisWeekExternalWorkouts.count
    }

    private var allDates: [Date] {
        var dates = Set<Date>()
        let calendar = Calendar.current
        for a in activities.prefix(50) { dates.insert(calendar.startOfDay(for: a.date)) }
        for w in externalWorkouts where !w.isFromThisApp { dates.insert(calendar.startOfDay(for: w.startDate)) }
        return dates.sorted(by: >)
    }

    private var hasAnyActivity: Bool {
        !activities.isEmpty || externalWorkouts.contains(where: { !$0.isFromThisApp })
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                ActivityLogFiltersSection.heroCard(
                    todayMinutes: todayMinutes,
                    todayCount: todayActivities.count + todayExternalWorkouts.count,
                    thisWeekMinutes: thisWeekMinutes,
                    thisWeekTotalCount: thisWeekTotalCount
                )
                ActivityLogFiltersSection.quickLogCard { type in
                    selectedType = type
                    showingAddSheet = true
                }

                if !hasAnyActivity && !isLoadingExternal {
                    ActivityLogListSection.emptyStateCard()
                } else {
                    ActivityLogListSection.timelineCard(
                        allDates: allDates,
                        activities: activities,
                        externalWorkouts: externalWorkouts,
                        weightUnit: weightUnit,
                        onDelete: { modelContext.delete($0) }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Activity Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    selectedType = .walk
                    showingAddSheet = true
                } label: { Image(systemName: "plus") }
            }
        }
        .task { await loadExternalWorkouts() }
        .refreshable { await loadExternalWorkouts() }
        .sheet(isPresented: $showingAddSheet) {
            AddActivitySheet(selectedType: selectedType) { type, minutes, notes, calories in
                let activity = ManualActivity(
                    activityType: type.rawValue,
                    durationMinutes: minutes,
                    notes: notes,
                    caloriesBurned: calories > 0 ? calories : nil
                )
                modelContext.insert(activity)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }
    }

    private func loadExternalWorkouts() async {
        isLoadingExternal = true
        defer { isLoadingExternal = false }
        externalWorkouts = (try? await appServices.healthDataCache.fetchExternalWorkouts(days: 30)) ?? []
    }
}

// MARK: - Add Activity Sheet

struct AddActivitySheet: View {
    @Environment(\.dismiss) private var dismiss
    var selectedType: ManualActivity.ActivityType
    let onSave: (ManualActivity.ActivityType, Int, String, Int) -> Void

    @State private var activityType: ManualActivity.ActivityType = .walk
    @State private var durationMinutes = 30
    @State private var notes = ""
    @State private var caloriesBurned = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Activity") {
                    Picker("Type", selection: $activityType) {
                        ForEach(ManualActivity.ActivityType.allCases) { type in
                            Label(type.rawValue, systemImage: type.icon).tag(type)
                        }
                    }
                }
                Section("Duration") {
                    Stepper("\(durationMinutes) minutes", value: $durationMinutes, in: 1...300, step: 5)
                }
                Section("Calories (optional)") {
                    Stepper("\(caloriesBurned) cal", value: $caloriesBurned, in: 0...2000, step: 25)
                }
                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical).lineLimit(2...4)
                }
            }
            .navigationTitle("Log Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(activityType, durationMinutes, notes, caloriesBurned)
                        dismiss()
                    }
                }
            }
            .onAppear { activityType = selectedType }
        }
    }
}

#Preview {
    NavigationStack { ActivityLogView() }
        .modelContainer(for: ManualActivity.self, inMemory: true)
}
