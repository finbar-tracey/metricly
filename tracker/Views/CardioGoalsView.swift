import SwiftUI
import SwiftData

struct CardioGoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsArray: [UserSettings]
    @Query(sort: \CardioSession.date, order: .reverse) private var sessions: [CardioSession]

    @State private var editingDistance = false
    @State private var editingSessions = false
    @State private var draftDistanceKm: Double = 0
    @State private var draftSessionCount: Int = 0

    private var settings: UserSettings? { settingsArray.first }
    private var useKm: Bool { settings?.useKilograms ?? true }
    private var distanceUnit: DistanceUnit { useKm ? .km : .mi }

    private var weekStart: Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .distantPast
    }

    private var thisWeekSessions: [CardioSession] {
        sessions.filter { $0.date >= weekStart }
    }

    private var thisWeekDistanceKm: Double {
        thisWeekSessions.reduce(0) { $0 + $1.distanceMeters } / 1000
    }

    private var distanceGoalKm: Double { settings?.weeklyCardioDistanceGoalKm ?? 0 }
    private var sessionGoal: Int       { settings?.weeklyCardioSessionGoal ?? 0 }

    private var distanceProgress: Double {
        guard distanceGoalKm > 0 else { return 0 }
        return min(1.0, thisWeekDistanceKm / distanceGoalKm)
    }

    private var sessionProgress: Double {
        guard sessionGoal > 0 else { return 0 }
        return min(1.0, Double(thisWeekSessions.count) / Double(sessionGoal))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                weeklyProgressCard
                setGoalsCard
                streakCard
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Cardio Goals")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            draftDistanceKm    = settings?.weeklyCardioDistanceGoalKm ?? 0
            draftSessionCount  = settings?.weeklyCardioSessionGoal ?? 0
        }
    }

    // MARK: - Weekly Progress

    private var weeklyProgressCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeader(title: "This Week", icon: "calendar.badge.checkmark", color: .orange)

            if distanceGoalKm == 0 && sessionGoal == 0 {
                HStack(spacing: 12) {
                    Image(systemName: "target")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("No goals set").font(.subheadline.weight(.semibold))
                        Text("Set a weekly distance or session goal below.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 16) {
                    if distanceGoalKm > 0 {
                        goalProgressRow(
                            title: "Distance",
                            icon: "ruler",
                            color: .orange,
                            current: String(format: "%.1f %@", distanceUnit.display(thisWeekDistanceKm), distanceUnit.label),
                            goal: String(format: "%.0f %@", distanceUnit.display(distanceGoalKm), distanceUnit.label),
                            progress: distanceProgress
                        )
                    }

                    if sessionGoal > 0 {
                        goalProgressRow(
                            title: "Sessions",
                            icon: "figure.run",
                            color: .blue,
                            current: "\(thisWeekSessions.count)",
                            goal: "\(sessionGoal)",
                            progress: sessionProgress
                        )
                    }
                }
            }
        }
        .appCard()
    }

    private func goalProgressRow(title: String, icon: String, color: Color,
                                 current: String, goal: String, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(color)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                }
                Spacer()
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(current)
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundStyle(color)
                    Text("/ \(goal)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.15))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(progress >= 1.0 ? Color.green : color)
                        .frame(width: geo.size.width * progress, height: 8)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 8)

            if progress >= 1.0 {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("Goal achieved!").font(.caption.weight(.semibold)).foregroundStyle(.green)
                }
            }
        }
    }

    // MARK: - Set Goals

    private var setGoalsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Set Goals", icon: "target", color: .purple)

            VStack(spacing: 0) {
                // Distance goal
                Button { editingDistance = true } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Weekly Distance")
                                .font(.subheadline.weight(.semibold))
                            Text("Set a distance target for each week")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(distanceGoalKm > 0
                             ? String(format: "%.0f %@", distanceUnit.display(distanceGoalKm), distanceUnit.label)
                             : "Not set")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(distanceGoalKm > 0 ? .orange : .secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                }
                .buttonStyle(.plain)

                Divider().padding(.horizontal, 16)

                // Session goal
                Button { editingSessions = true } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Weekly Sessions")
                                .font(.subheadline.weight(.semibold))
                            Text("How many cardio sessions per week")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(sessionGoal > 0
                             ? "\(sessionGoal) session\(sessionGoal == 1 ? "" : "s")"
                             : "Not set")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(sessionGoal > 0 ? .blue : .secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
        .sheet(isPresented: $editingDistance) {
            distanceGoalSheet
        }
        .sheet(isPresented: $editingSessions) {
            sessionGoalSheet
        }
    }

    private var distanceGoalSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(
                        value: $draftDistanceKm,
                        in: 0...500,
                        step: distanceUnit.stepSize
                    ) {
                        HStack {
                            Text("Distance")
                            Spacer()
                            Text(draftDistanceKm > 0
                                 ? String(format: "%.0f %@", distanceUnit.display(draftDistanceKm), distanceUnit.label)
                                 : "Off")
                                .foregroundStyle(draftDistanceKm > 0 ? .primary : .secondary)
                        }
                    }
                } footer: {
                    Text("Set to 0 to disable this goal.")
                }
            }
            .navigationTitle("Weekly Distance Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        draftDistanceKm = settings?.weeklyCardioDistanceGoalKm ?? 0
                        editingDistance = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        settings?.weeklyCardioDistanceGoalKm = draftDistanceKm
                        modelContext.saveOrLog()
                        editingDistance = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var sessionGoalSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $draftSessionCount, in: 0...14) {
                        HStack {
                            Text("Sessions per week")
                            Spacer()
                            Text(draftSessionCount > 0 ? "\(draftSessionCount)" : "Off")
                                .foregroundStyle(draftSessionCount > 0 ? .primary : .secondary)
                        }
                    }
                } footer: {
                    Text("Set to 0 to disable this goal.")
                }
            }
            .navigationTitle("Weekly Session Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        draftSessionCount = settings?.weeklyCardioSessionGoal ?? 0
                        editingSessions = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        settings?.weeklyCardioSessionGoal = draftSessionCount
                        modelContext.saveOrLog()
                        editingSessions = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Streak Card

    private var streakCard: some View {
        let streak = currentStreak
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Activity Streak", icon: "flame.fill", color: .red)

            HStack(spacing: 20) {
                ZStack {
                    Circle().fill(Color.red.opacity(0.12)).frame(width: 70, height: 70)
                    VStack(spacing: 1) {
                        Text("\(streak)")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(.red)
                        Text("weeks")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(streak == 0 ? "No streak yet" : "\(streak) week\(streak == 1 ? "" : "s") in a row")
                        .font(.subheadline.weight(.semibold))
                    Text(streak == 0
                         ? "Complete a cardio session this week to start your streak."
                         : "Keep going — don't break the chain!")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    private var currentStreak: Int {
        // Count consecutive weeks (ending this week) that had at least one session
        var streak = 0
        var weekOffset = 0
        let calendar = Calendar.current
        while true {
            guard let weekInterval = calendar.dateInterval(
                of: .weekOfYear,
                for: calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: .now) ?? .now
            ) else { break }
            let hadSession = sessions.contains { $0.date >= weekInterval.start && $0.date < weekInterval.end }
            if hadSession { streak += 1; weekOffset += 1 } else { break }
        }
        return streak
    }
}
