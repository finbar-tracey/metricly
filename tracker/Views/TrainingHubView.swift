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
    private var inProgressWorkout: Workout? { workouts.first { $0.endTime == nil } }
    private var currentStreak: Int { Workout.currentStreak(from: workouts, cardioSessions: cardioSessions) }
    private var uniqueExerciseCount: Int {
        Set(finishedWorkouts.flatMap { $0.exercises.map { $0.name.lowercased() } }).count
    }

    private var weeklyCardioKm: Double {
        let start = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        return cardioSessions
            .filter { $0.date >= start }
            .reduce(0) { $0 + $1.distanceMeters } / 1000
    }
    private var lastSession: CardioSession? { cardioSessions.first }

    var body: some View {
        List {
            Section {
                TrainingHubSections.trainingHeroCard(
                    finishedWorkoutCount: finishedWorkouts.count,
                    currentStreak: currentStreak,
                    uniqueExerciseCount: uniqueExerciseCount,
                    weeklyCardioKm: weeklyCardioKm,
                    weightUnit: weightUnit,
                    onStartWorkout: { showingAddWorkout = true }
                )
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
            }

            if let active = inProgressWorkout {
                Section {
                    NavigationLink(value: active) {
                        TrainingHubSections.resumeRow(active)
                    }
                }
            }

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

            Section {
                NavigationLink { CardioHubView() } label: {
                    TrainingHubSections.cardioHeroRow(
                        lastSession: lastSession,
                        weeklyCardioKm: weeklyCardioKm,
                        weightUnit: weightUnit
                    )
                }
                NavigationLink { ActivityLogView() } label: {
                    hubRow(icon: "list.bullet.rectangle", color: .mint,
                           title: "Activity Log", subtitle: "Manual activity logging")
                }
            } header: {
                Text("Cardio & Activity")
            }

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
}
