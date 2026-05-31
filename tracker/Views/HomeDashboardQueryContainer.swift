import SwiftUI
import SwiftData

/// Holds all SwiftData `@Query` properties for Home; builds snapshot for the screen.
struct HomeDashboardQueryContainer: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Workout> { $0.isTemplate }, sort: \Workout.name)
    private var templates: [Workout]
    @Query(filter: #Predicate<Workout> { !$0.isTemplate && $0.endTime != nil }, sort: \Workout.date, order: .reverse)
    private var finishedWorkouts: [Workout]
    @Query(filter: #Predicate<Workout> { !$0.isTemplate }, sort: \Workout.date, order: .reverse)
    private var allWorkouts: [Workout]
    @Query private var settingsArray: [UserSettings]
    @Query(sort: \CaffeineEntry.date, order: .reverse) private var caffeineEntries: [CaffeineEntry]
    @Query(sort: \WaterEntry.date, order: .reverse) private var waterEntries: [WaterEntry]
    @Query(sort: \CreatineEntry.date, order: .reverse) private var creatineEntries: [CreatineEntry]
    @Query(sort: \CardioSession.date, order: .reverse) private var cardioSessions: [CardioSession]
    @Query(sort: \SorenessEntry.date, order: .reverse) private var sorenessReports: [SorenessEntry]
    @Query(sort: \PlanComplianceEvent.day, order: .reverse) private var complianceEvents: [PlanComplianceEvent]
    @Query(sort: \WorkoutFeedbackEvent.day, order: .reverse) private var feedbackEvents: [WorkoutFeedbackEvent]
    @Query(sort: \TrainingBlock.startDate, order: .reverse) private var trainingBlocks: [TrainingBlock]

    @State private var dashboardStore = HomeDashboardStore()

    private func refreshSnapshot() {
        dashboardStore.refreshSnapshot(
            templates: templates,
            finishedWorkouts: finishedWorkouts,
            allWorkouts: allWorkouts,
            settingsArray: settingsArray,
            caffeineEntries: caffeineEntries,
            waterEntries: waterEntries,
            creatineEntries: creatineEntries,
            cardioSessions: cardioSessions,
            sorenessReports: sorenessReports,
            complianceEvents: complianceEvents,
            feedbackEvents: feedbackEvents,
            trainingBlocks: trainingBlocks
        )
    }

    private func recomputeRecoveryAndPlan(
        liveHealthSignals: HealthSignals,
        externalWorkouts: [ExternalWorkout]
    ) {
        refreshSnapshot()
        let snap = dashboardStore.snapshot
        dashboardStore.recompute(
            finishedWorkouts: snap.finishedWorkouts,
            cardioSessions: snap.cardioSessions,
            sorenessReports: snap.sorenessReports,
            complianceEvents: snap.complianceEvents,
            feedbackEvents: snap.feedbackEvents,
            trainingBlocks: snap.trainingBlocks,
            health: liveHealthSignals,
            externalWorkouts: externalWorkouts,
            scheduledName: snap.settings.weeklyPlan[snap.todayWeekday],
            todayWeekday: snap.todayWeekday,
            todaysWorkouts: snap.todaysWorkouts,
            settings: snap.settings
        )
    }

    private func buildProgressionSuggestions(into suggestions: Binding<[HomeProgressionSuggestion]>) {
        let snapshot = allWorkouts
        Task(priority: .utility) {
            let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .distantPast
            let recentWorkouts = snapshot.filter { $0.endTime != nil && $0.date >= twoWeeksAgo }
            var seen = Set<String>()
            var exerciseNames: [String] = []
            for workout in recentWorkouts {
                for exercise in workout.exercises {
                    let key = exercise.name.lowercased()
                    if !seen.contains(key) { seen.insert(key); exerciseNames.append(exercise.name) }
                }
            }
            var built: [HomeProgressionSuggestion] = []
            let allExercisesFlat = snapshot.flatMap(\.exercises)
            for name in exerciseNames {
                let history = allExercisesFlat
                    .filter { $0.name.lowercased() == name.lowercased() && !(($0.workout?.isTemplate) ?? true) && !$0.sets.isEmpty }
                    .sorted { ($0.workout?.date ?? .distantPast) > ($1.workout?.date ?? .distantPast) }
                let sessions = ProgressionAdvisor.buildSessions(from: history)
                guard sessions.count >= 2 else { continue }
                let rec = ProgressionAdvisor.recommend(sessions: sessions, muscleGroup: history.first?.category)
                if case .increase = rec.action {
                    built.append(HomeProgressionSuggestion(exerciseName: name, recommendation: rec))
                }
            }
            let result = Array(built.sorted { $0.recommendation.confidence > $1.recommendation.confidence }.prefix(3))
            await MainActor.run { suggestions.wrappedValue = result }
        }
    }

    private func quickStartWorkout() {
        let snap = dashboardStore.snapshot
        let adaptive: String? = {
            guard dashboardStore.todayPlan.intensity != .rest,
                  !dashboardStore.todayPlan.recommendedName.isEmpty,
                  dashboardStore.todayPlan.recommendedName != "—" else { return nil }
            return dashboardStore.todayPlan.recommendedName
        }()
        let weekday = Calendar.current.component(.weekday, from: .now)
        let planName = adaptive ?? snap.settings.weeklyPlan[weekday] ?? ""
        let name = planName.isEmpty
            ? "Workout - \(Date.now.formatted(.dateTime.month(.abbreviated).day()))"
            : planName

        let workout = Workout(name: name, date: .now)
        modelContext.insert(workout)

        if !planName.isEmpty,
           let template = snap.templates.first(where: {
               $0.name.localizedCaseInsensitiveCompare(planName) == .orderedSame
           }) {
            workout.copyExercises(from: template.exercises, into: modelContext)
        }

        if adaptive != nil,
           !workout.exercises.isEmpty,
           dashboardStore.todayPlan.intensity != .rest {
            TodayPlanApply.apply(
                plan: dashboardStore.todayPlan,
                to: workout,
                in: modelContext,
                currentBlock: TrainingBlockEngine.currentBlock(in: snap.trainingBlocks)
            )
        }

        modelContext.saveOrLog()
        if adaptive != nil, dashboardStore.todayPlan.intensity != .rest {
            AppLifecycleCoordinator.refreshExtensions(modelContainer: modelContext.container)
        }
        HapticsManager.workoutStarted()
    }

    private func repeatLastWorkout() {
        guard let last = dashboardStore.snapshot.allWorkouts.first else { return }
        let baseName = last.name.components(separatedBy: " - ").first ?? last.name
        let newName = "\(baseName) - \(Date.now.formatted(.dateTime.month(.abbreviated).day()))"
        let workout = Workout(name: newName, date: .now)
        modelContext.insert(workout)
        workout.copyExercises(from: last.exercises, into: modelContext)
        modelContext.saveOrLog()
    }

    var body: some View {
        HomeDashboardScreen(
            store: dashboardStore,
            onRefreshSnapshot: refreshSnapshot,
            onRecompute: { health, external in
                recomputeRecoveryAndPlan(liveHealthSignals: health, externalWorkouts: external)
            },
            onBuildProgression: buildProgressionSuggestions,
            onQuickStart: quickStartWorkout,
            onRepeatLast: repeatLastWorkout
        )
        .onAppear { refreshSnapshot() }
        .onChange(of: allWorkouts.count) { refreshSnapshot() }
        .onChange(of: finishedWorkouts.count) {
            refreshSnapshot()
        }
        .onChange(of: cardioSessions.count) {
            refreshSnapshot()
        }
    }
}

