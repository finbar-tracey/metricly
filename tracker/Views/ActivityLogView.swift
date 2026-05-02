import SwiftUI
import SwiftData

struct ActivityLogView: View {
    @Environment(\.modelContext) private var modelContext
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

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                heroCard
                quickLogCard

                if activities.isEmpty && externalWorkouts.filter({ !$0.isFromThisApp }).isEmpty && !isLoadingExternal {
                    emptyStateCard
                } else {
                    timelineCard
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

    // MARK: - Hero Card

    private var heroCard: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color.green, Color.teal.opacity(0.7)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(.white.opacity(0.07)).frame(width: 200).offset(x: 160, y: -60)

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle().fill(.white.opacity(0.20)).frame(width: 52, height: 52)
                        Image(systemName: "figure.mixed.cardio")
                            .font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Today's Activity")
                            .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.75))
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(todayMinutes)")
                                .font(.system(size: 36, weight: .black, design: .rounded))
                                .foregroundStyle(.white).monospacedDigit()
                            Text("min").font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.75))
                        }
                    }
                    Spacer()
                    let todayCount = todayActivities.count + todayExternalWorkouts.count
                    if todayCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill").font(.caption.bold())
                            Text("\(todayCount) logged").font(.caption.bold())
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.white.opacity(0.20), in: Capsule())
                        .foregroundStyle(.white)
                    }
                }

                HStack(spacing: 0) {
                    HeroStatCol(value: "\(thisWeekMinutes)m", label: "This Week")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 28)
                    HeroStatCol(value: "\(thisWeekTotalCount)", label: "Activities")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 28)
                    HeroStatCol(value: "\(todayMinutes)m", label: "Today")
                }
            }
            .padding(20)
        }
        .heroCard()
    }


    // MARK: - Quick Log Card

    private var quickLogCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Log Activity", icon: "plus.circle.fill", color: .green)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ManualActivity.ActivityType.allCases) { type in
                        Button {
                            selectedType = type
                            showingAddSheet = true
                        } label: {
                            VStack(spacing: 5) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(colorFor(type).opacity(0.12))
                                        .frame(width: 52, height: 52)
                                    Image(systemName: type.icon)
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(colorFor(type))
                                }
                                Text(type.rawValue)
                                    .font(.caption2.bold())
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                            }
                            .frame(width: 64)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .appCard()
    }

    // MARK: - Timeline Card

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "History", icon: "clock.fill", color: .secondary)

            VStack(spacing: 12) {
                ForEach(allDates, id: \.self) { date in
                    daySection(for: date)
                }
            }
        }
        .appCard()
    }

    private func daySection(for date: Date) -> some View {
        let dayExternal = externalWorkouts.filter {
            !$0.isFromThisApp && Calendar.current.isDate($0.startDate, inSameDayAs: date)
        }.sorted { $0.startDate > $1.startDate }

        let dayManual = activities.filter {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }

        return VStack(alignment: .leading, spacing: 0) {
            Text(date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemGroupedBackground).opacity(0.6))

            ForEach(dayExternal) { workout in
                externalWorkoutRow(workout)
                Divider().padding(.leading, 62)
            }

            ForEach(Array(dayManual.enumerated()), id: \.element.id) { idx, activity in
                activityRow(activity)
                    .contextMenu {
                        Button(role: .destructive) { modelContext.delete(activity) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                if idx < dayManual.count - 1 || !dayExternal.isEmpty {
                    Divider().padding(.leading, 62)
                }
            }
        }
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Row Views

    private func activityRow(_ activity: ManualActivity) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(colorFor(activity.type).opacity(0.12)).frame(width: 40, height: 40)
                Image(systemName: activity.type.icon)
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(colorFor(activity.type))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.type.rawValue).font(.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                    Text("\(activity.durationMinutes) min").font(.caption).foregroundStyle(.secondary)
                    if let cal = activity.caloriesBurned {
                        Text("· \(cal) cal").font(.caption).foregroundStyle(.secondary)
                    }
                    Text(activity.date, format: .dateTime.hour().minute())
                        .font(.caption).foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
    }

    private func externalWorkoutRow(_ workout: ExternalWorkout) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color.teal.opacity(0.12)).frame(width: 40, height: 40)
                Image(systemName: workout.icon)
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(.teal)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(workout.displayName).font(.subheadline.weight(.semibold))
                    Text(workout.sourceName).font(.caption2).foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(.teal.opacity(0.6), in: Capsule())
                }
                HStack(spacing: 6) {
                    Text(formatDuration(workout.duration)).font(.caption).foregroundStyle(.secondary)
                    if let cal = workout.totalCalories, cal > 0 {
                        Text("· \(Int(cal)) cal").font(.caption).foregroundStyle(.secondary)
                    }
                    if let dist = workout.totalDistance, dist > 0 {
                        Text("· \(String(format: "%.1f", dist / 1000)) km").font(.caption).foregroundStyle(.secondary)
                    }
                    Text(workout.startDate, format: .dateTime.hour().minute())
                        .font(.caption).foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
    }

    // MARK: - Empty State

    private var emptyStateCard: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(Color.green.opacity(0.12)).frame(width: 70, height: 70)
                Image(systemName: "figure.mixed.cardio")
                    .font(.system(size: 28, weight: .semibold)).foregroundStyle(.green)
            }
            VStack(spacing: 6) {
                Text("No Activities Yet").font(.headline)
                Text("Log walks, rides, stretching, and other activities. Workouts synced from Apple Health will also appear.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
        .appCard()
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        return mins >= 60 ? "\(mins / 60)h \(mins % 60)m" : "\(mins) min"
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
