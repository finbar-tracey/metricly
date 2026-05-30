import SwiftUI
import SwiftData

struct CardioGoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.weightUnit) private var weightUnit
    @Query private var settingsArray: [UserSettings]
    @Query(sort: \CardioSession.date, order: .reverse) private var sessions: [CardioSession]

    @State private var editingDistance = false
    @State private var editingSessions = false
    @State private var draftDistanceKm: Double = 0
    @State private var draftSessionCount: Int = 0

    private var settings: UserSettings? { settingsArray.first }
    private var distanceUnit: DistanceUnit { weightUnit.distanceUnit }

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
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.orange, AppTheme.Signal.actionOrange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                            .shadow(color: .orange.opacity(0.40), radius: 6, y: 3)
                        Image(systemName: "target")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("No goals set")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        Text("Set a weekly distance or session goal below.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [Color.orange.opacity(0.10), Color.orange.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.orange.opacity(0.20), lineWidth: 0.5)
                )
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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 7) {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.16))
                            .frame(width: 28, height: 28)
                        Image(systemName: icon)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(color)
                    }
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                Spacer()
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(current)
                        .font(.system(size: 17, weight: .black, design: .rounded).monospacedDigit())
                        .foregroundStyle(color)
                    Text("/ \(goal)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            GradientProgressBar(value: progress, color: progress >= 1.0 ? .green : color, height: 10)

            if progress >= 1.0 {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption.bold())
                    Text("Goal achieved!")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.green)
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color.green.opacity(0.12), in: Capsule())
                .overlay(Capsule().stroke(Color.green.opacity(0.20), lineWidth: 0.5))
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
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [.orange, AppTheme.Signal.actionOrange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 36, height: 36)
                                .shadow(color: .orange.opacity(0.40), radius: 5, y: 2)
                            Image(systemName: "ruler")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Weekly Distance")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                            Text("Set a distance target for each week")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(distanceGoalKm > 0
                             ? String(format: "%.0f %@", distanceUnit.display(distanceGoalKm), distanceUnit.label)
                             : "Not set")
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(distanceGoalKm > 0 ? .orange : .secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                }
                .buttonStyle(.pressableCard)

                Divider().padding(.horizontal, 16)

                // Session goal
                Button { editingSessions = true } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, AppTheme.Signal.calm],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 36, height: 36)
                                .shadow(color: .blue.opacity(0.40), radius: 5, y: 2)
                            Image(systemName: "calendar.badge.checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Weekly Sessions")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                            Text("How many cardio sessions per week")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(sessionGoal > 0
                             ? "\(sessionGoal) session\(sessionGoal == 1 ? "" : "s")"
                             : "Not set")
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(sessionGoal > 0 ? .blue : .secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                }
                .buttonStyle(.pressableCard)
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.cardHairline, lineWidth: 0.5)
            )
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
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.red.opacity(0.18), Color.red.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 78, height: 78)
                        .overlay(Circle().stroke(Color.red.opacity(0.20), lineWidth: 1))
                    VStack(spacing: 2) {
                        AnimatedInt(
                            value: streak,
                            font: .system(size: 30, weight: .black, design: .rounded),
                            color: .red
                        )
                        Text("WEEKS")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(0.5)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(streak == 0 ? "No streak yet" : "\(streak) week\(streak == 1 ? "" : "s") in a row")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text(streak == 0
                         ? "Complete a cardio session this week to start your streak."
                         : "Keep going — don't break the chain!")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color.red.opacity(0.08), Color(.tertiarySystemGroupedBackground)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.red.opacity(0.12), lineWidth: 0.5)
            )
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
