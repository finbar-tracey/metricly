import SwiftUI
import SwiftData

struct ActivityLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ManualActivity.date, order: .reverse) private var activities: [ManualActivity]

    @State private var showingAddSheet = false
    @State private var externalWorkouts: [ExternalWorkout] = []
    @State private var isLoadingExternal = true

    private var todayActivities: [ManualActivity] {
        let start = Calendar.current.startOfDay(for: .now)
        return activities.filter { $0.date >= start }
    }

    private var todayExternalWorkouts: [ExternalWorkout] {
        let start = Calendar.current.startOfDay(for: .now)
        return externalWorkouts.filter { $0.startDate >= start && !$0.isFromThisApp }
    }

    private var todayMinutes: Int {
        let manual = todayActivities.reduce(0) { $0 + $1.durationMinutes }
        let external = todayExternalWorkouts.reduce(0) { $0 + Int($1.duration / 60) }
        return manual + external
    }

    private var thisWeekActivities: [ManualActivity] {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return [] }
        return activities.filter { $0.date >= weekStart }
    }

    private var thisWeekExternalWorkouts: [ExternalWorkout] {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return [] }
        return externalWorkouts.filter { $0.startDate >= weekStart && !$0.isFromThisApp }
    }

    private var thisWeekMinutes: Int {
        let manual = thisWeekActivities.reduce(0) { $0 + $1.durationMinutes }
        let external = thisWeekExternalWorkouts.reduce(0) { $0 + Int($1.duration / 60) }
        return manual + external
    }

    private var thisWeekTotalCount: Int {
        thisWeekActivities.count + thisWeekExternalWorkouts.count
    }

    // Group manual activities by date
    private var groupedActivities: [(date: Date, activities: [ManualActivity])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: activities.prefix(50)) { calendar.startOfDay(for: $0.date) }
        return grouped.map { (date: $0.key, activities: $0.value) }.sorted { $0.date > $1.date }
    }

    // Group external workouts by date (excluding this app's workouts)
    private var groupedExternalWorkouts: [(date: Date, workouts: [ExternalWorkout])] {
        let calendar = Calendar.current
        let filtered = externalWorkouts.filter { !$0.isFromThisApp }
        let grouped = Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.startDate) }
        return grouped.map { (date: $0.key, workouts: $0.value) }.sorted { $0.date > $1.date }
    }

    // Merged timeline: all dates that have either manual or external activities
    private var allDates: [Date] {
        var dates = Set<Date>()
        let calendar = Calendar.current
        for a in activities.prefix(50) { dates.insert(calendar.startOfDay(for: a.date)) }
        for w in externalWorkouts where !w.isFromThisApp { dates.insert(calendar.startOfDay(for: w.startDate)) }
        return dates.sorted(by: >)
    }

    var body: some View {
        List {
            // Summary
            Section {
                HStack {
                    VStack(spacing: 4) {
                        Text("\(todayMinutes)")
                            .font(.title2.bold().monospacedDigit())
                        Text("Today (min)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    Divider().frame(height: 36)

                    VStack(spacing: 4) {
                        Text("\(thisWeekMinutes)")
                            .font(.title2.bold().monospacedDigit())
                        Text("This Week")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    Divider().frame(height: 36)

                    VStack(spacing: 4) {
                        Text("\(thisWeekTotalCount)")
                            .font(.title2.bold().monospacedDigit())
                        Text("Activities")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 8)
            }

            // Quick Add
            Section("Log Activity") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(ManualActivity.ActivityType.allCases) { type in
                            Button {
                                showingAddSheet = true
                                selectedType = type
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: type.icon)
                                        .font(.system(size: 18))
                                        .foregroundStyle(colorFor(type))
                                    Text(type.rawValue)
                                        .font(.caption2)
                                }
                                .frame(width: 64, height: 55)
                                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            // Merged history
            if activities.isEmpty && externalWorkouts.filter({ !$0.isFromThisApp }).isEmpty && !isLoadingExternal {
                Section {
                    ContentUnavailableView {
                        Label("No Activities", systemImage: "figure.mixed.cardio")
                    } description: {
                        Text("Log walks, rides, stretching, and other activities here.\nWorkouts synced from Apple Health will also appear.")
                    }
                }
            } else {
                ForEach(allDates, id: \.self) { date in
                    Section {
                        // External workouts for this date
                        let dayExternal = externalWorkouts.filter {
                            !$0.isFromThisApp && Calendar.current.isDate($0.startDate, inSameDayAs: date)
                        }.sorted { $0.startDate > $1.startDate }

                        ForEach(dayExternal) { workout in
                            externalWorkoutRow(workout)
                        }

                        // Manual activities for this date
                        let dayManual = activities.filter {
                            Calendar.current.isDate($0.date, inSameDayAs: date)
                        }

                        ForEach(dayManual) { activity in
                            activityRow(activity)
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                modelContext.delete(dayManual[index])
                            }
                        }
                    } header: {
                        Text(date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                    }
                }
            }
        }
        .navigationTitle("Activity Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    selectedType = .walk
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            await loadExternalWorkouts()
        }
        .refreshable {
            await loadExternalWorkouts()
        }
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

    @State private var selectedType: ManualActivity.ActivityType = .walk

    private func activityRow(_ activity: ManualActivity) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorFor(activity.type).opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: activity.type.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(colorFor(activity.type))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.type.rawValue)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                    Text("\(activity.durationMinutes) min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let cal = activity.caloriesBurned {
                        Text("· \(cal) cal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(activity.date, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
    }

    private func externalWorkoutRow(_ workout: ExternalWorkout) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.teal.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: workout.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.teal)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(workout.displayName)
                        .font(.subheadline.weight(.semibold))
                    Text(workout.sourceName)
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.teal.opacity(0.6), in: Capsule())
                }
                HStack(spacing: 6) {
                    Text(formatDuration(workout.duration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let cal = workout.totalCalories, cal > 0 {
                        Text("· \(Int(cal)) cal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let dist = workout.totalDistance, dist > 0 {
                        Text("· \(String(format: "%.1f", dist / 1000)) km")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(workout.startDate, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        if mins >= 60 {
            return "\(mins / 60)h \(mins % 60)m"
        }
        return "\(mins) min"
    }

    private func loadExternalWorkouts() async {
        isLoadingExternal = true
        defer { isLoadingExternal = false }
        externalWorkouts = (try? await HealthKitManager.shared.fetchExternalWorkouts(days: 30)) ?? []
    }

    private func colorFor(_ type: ManualActivity.ActivityType) -> Color {
        switch type.color {
        case "green": return .green
        case "orange": return .orange
        case "blue": return .blue
        case "cyan": return .cyan
        case "brown": return .brown
        case "purple": return .purple
        case "indigo": return .indigo
        case "red": return .red
        default: return .gray
        }
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
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Log Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(activityType, durationMinutes, notes, caloriesBurned)
                        dismiss()
                    }
                }
            }
            .onAppear {
                activityType = selectedType
            }
        }
    }
}

#Preview {
    NavigationStack {
        ActivityLogView()
    }
    .modelContainer(for: ManualActivity.self, inMemory: true)
}
