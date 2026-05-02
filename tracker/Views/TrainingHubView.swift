import SwiftUI
import SwiftData

struct TrainingHubView: View {
    @Query(filter: #Predicate<Workout> { !$0.isTemplate }, sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]
    @Query(sort: \CardioSession.date, order: .reverse)
    private var cardioSessions: [CardioSession]
    @Environment(\.weightUnit) private var weightUnit

    private var finishedWorkouts: [Workout] { workouts.filter { $0.endTime != nil } }
    private var currentStreak: Int { Workout.currentStreak(from: workouts, cardioSessions: cardioSessions) }
    private var uniqueExerciseCount: Int {
        Set(finishedWorkouts.flatMap { $0.exercises.map { $0.name.lowercased() } }).count
    }

    // Cardio stats
    private var weeklyCardioKm: Double {
        let start = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        return cardioSessions
            .filter { $0.date >= start }
            .reduce(0) { $0 + $1.distanceMeters } / 1000
    }
    private var lastSession: CardioSession? { cardioSessions.first }

    var body: some View {
        List {
            // ── Hero stats strip ──────────────────────────────────────────
            Section {
                HStack(spacing: 0) {
                    heroStat(value: "\(finishedWorkouts.count)",
                             label: "Workouts",
                             icon: "figure.strengthtraining.traditional",
                             color: .blue)
                    Divider().frame(height: 44)
                    heroStat(value: "\(currentStreak)",
                             label: "Streak",
                             icon: "flame.fill",
                             color: .orange)
                    Divider().frame(height: 44)
                    heroStat(value: "\(uniqueExerciseCount)",
                             label: "Exercises",
                             icon: "dumbbell.fill",
                             color: .purple)
                    Divider().frame(height: 44)
                    heroStat(
                        value: weeklyCardioKm > 0.05 ? weightUnit.distanceUnit.format(weeklyCardioKm) : "—",
                        label: "\(weightUnit.distanceUnit.label) this wk",
                        icon: "figure.run",
                        color: .green
                    )
                }
                .padding(.vertical, 8)
            }

            // ── Workouts ─────────────────────────────────────────────────
            Section("Workouts") {
                NavigationLink { FullWorkoutListView() } label: {
                    hubRow(icon: "dumbbell", color: .blue,
                           title: "All Workouts", subtitle: "Complete workout history")
                }
                NavigationLink { WorkoutScheduleView() } label: {
                    hubRow(icon: "calendar.badge.checkmark", color: .green,
                           title: "Weekly Schedule", subtitle: "Plan workouts for each day")
                }
                NavigationLink { TrainingProgramsView() } label: {
                    hubRow(icon: "calendar.badge.clock", color: .purple,
                           title: "Programs", subtitle: "Structured training plans")
                }
                NavigationLink { WorkoutCalendarView() } label: {
                    hubRow(icon: "calendar", color: .teal,
                           title: "Calendar", subtitle: "Monthly training view")
                }
            }

            // ── Cardio & Activity ────────────────────────────────────────
            Section {
                NavigationLink { CardioHubView() } label: {
                    cardioHeroRow()
                }
                NavigationLink { ActivityLogView() } label: {
                    hubRow(icon: "list.bullet.rectangle", color: .mint,
                           title: "Activity Log", subtitle: "Manual activity logging")
                }
            } header: {
                Text("Cardio & Activity")
            }

            // ── Analyze ──────────────────────────────────────────────────
            Section("Analyze") {
                NavigationLink { InsightsView() } label: {
                    hubRow(icon: "chart.bar", color: .green,
                           title: "Insights", subtitle: "Training analytics & trends")
                }
                NavigationLink { WorkoutComparisonView() } label: {
                    hubRow(icon: "arrow.left.arrow.right", color: .indigo,
                           title: "Compare Workouts", subtitle: "Side-by-side analysis")
                }
                NavigationLink { SmartSuggestionsView() } label: {
                    hubRow(icon: "brain.head.profile", color: .purple,
                           title: "Smart Suggestions", subtitle: "AI-driven workout ideas")
                }
            }

            // ── Progress ─────────────────────────────────────────────────
            Section("Progress") {
                NavigationLink { PersonalRecordsView() } label: {
                    hubRow(icon: "trophy", color: .orange,
                           title: "Personal Records", subtitle: "Your heaviest lifts")
                }
                NavigationLink { StreakCalendarView() } label: {
                    hubRow(icon: "flame", color: .red,
                           title: "Streak", subtitle: "Workout consistency")
                }
                NavigationLink { LiftGoalsView() } label: {
                    hubRow(icon: "target", color: .green,
                           title: "Lift Goals", subtitle: "Progressive overload targets")
                }
            }
        }
        .navigationTitle("Training")
    }

    // MARK: - Subviews

    private func heroStat(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 5) {
            ZStack {
                Circle().fill(color.opacity(0.12)).frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    /// A richer row for the primary "Run & Cardio" entry — shows last session inline.
    private func cardioHeroRow() -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.orange.opacity(0.14))
                    .frame(width: 40, height: 40)
                Image(systemName: "figure.run")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Run & Cardio")
                    .font(.body)
                if let last = lastSession {
                    Text(lastSessionSummary(last))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("GPS tracking, splits, pace & route")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if weeklyCardioKm > 0.05 {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(weightUnit.distanceUnit.format(weeklyCardioKm))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                        .monospacedDigit()
                    Text("this week")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func lastSessionSummary(_ s: CardioSession) -> String {
        let dist = s.distanceMeters > 0
            ? String(format: "%.2f km", s.distanceMeters / 1000)
            : s.formattedDuration
        let ago = s.date.formatted(.relative(presentation: .named, unitsStyle: .abbreviated))
        return "\(s.type.shortName) · \(dist) · \(ago)"
    }
}

