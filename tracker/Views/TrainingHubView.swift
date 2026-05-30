import SwiftUI
import SwiftData

struct TrainingHubView: View {
    @Query(filter: #Predicate<Workout> { !$0.isTemplate }, sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]
    @Query(sort: \CardioSession.date, order: .reverse)
    private var cardioSessions: [CardioSession]
    @Environment(\.weightUnit) private var weightUnit
    @State private var showingAddWorkout = false

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
            // ── Hero card + Start CTA ─────────────────────────────────────
            Section {
                trainingHeroCard
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
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
                           title: "Smart Suggestions", subtitle: "Recovery-based workout ideas")
                }
            }

            // ── Progress ─────────────────────────────────────────────────
            // Canonical: this section's contents must match the iPad
            // sidebar's "Progress" section in ContentView. The two have
            // drifted before (Achievements was in MoreHub on iPhone for
            // a while). If you add a row here, mirror it there.
            Section("Progress") {
                NavigationLink { PersonalRecordsView() } label: {
                    hubRow(icon: "trophy", color: .orange,
                           title: "Personal Records", subtitle: "Your heaviest lifts")
                }
                NavigationLink { AchievementsView() } label: {
                    hubRow(icon: "medal", color: .yellow,
                           title: "Achievements", subtitle: "Badges and milestones")
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
        .scrollContentBackground(.hidden)
        .tabBackground(tint: AppTheme.Signal.calm, height: 320)
        .navigationTitle("Training")
        .sheet(isPresented: $showingAddWorkout) {
            AddWorkoutSheet()
        }
    }

    // MARK: - Subviews

    /// Calm-gradient hero — gives Training the same hero treatment as the
    /// other tabs, and carries the primary "Start Workout" CTA the hub was
    /// missing. Stats: workouts · streak · unique exercises · cardio this week.
    private var trainingHeroCard: some View {
        HeroCard(palette: AppTheme.Gradients.calm) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 6) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("Training")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .tracking(0.5)
                        .textCase(.uppercase)
                }

                HStack(spacing: 0) {
                    HeroStatCol(value: "\(finishedWorkouts.count)", label: "Workouts",
                                icon: "figure.strengthtraining.traditional")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 40)
                    HeroStatCol(value: "\(currentStreak)", label: "Streak", icon: "flame.fill")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 40)
                    HeroStatCol(value: "\(uniqueExerciseCount)", label: "Exercises", icon: "dumbbell.fill")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 40)
                    HeroStatCol(value: weeklyCardioKm > 0.05 ? weightUnit.distanceUnit.format(weeklyCardioKm) : "—",
                                label: "\(weightUnit.distanceUnit.label) this wk", icon: "figure.run")
                }
                .padding(.vertical, 12)
                .background(.ultraThinMaterial.opacity(0.55), in: RoundedRectangle(cornerRadius: AppTheme.miniCardRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.miniCardRadius, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 0.5)
                )

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showingAddWorkout = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("Start Workout")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(AppTheme.Signal.calm)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                }
                .buttonStyle(.pressableCard)
            }
            .padding(20)
        }
        .frame(minHeight: 145)
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

