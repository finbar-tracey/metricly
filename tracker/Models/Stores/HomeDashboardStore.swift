import Foundation

/// Home screen adaptive plan + recovery state (orchestration, not layout).
@MainActor @Observable
final class HomeDashboardStore {
    var recoveryResult: RecoveryResult = .empty
    var todayPlan: TodayPlan = .empty
    var snapshot: HomeDashboardSnapshot = HomeDashboardSnapshot()

    func refreshSnapshot(
        templates: [Workout],
        finishedWorkouts: [Workout],
        allWorkouts: [Workout],
        settingsArray: [UserSettings],
        caffeineEntries: [CaffeineEntry],
        waterEntries: [WaterEntry],
        creatineEntries: [CreatineEntry],
        cardioSessions: [CardioSession],
        sorenessReports: [SorenessEntry],
        complianceEvents: [PlanComplianceEvent],
        feedbackEvents: [WorkoutFeedbackEvent],
        trainingBlocks: [TrainingBlock]
    ) {
        snapshot = .build(
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

    func recompute(
        finishedWorkouts: [Workout],
        cardioSessions: [CardioSession],
        sorenessReports: [SorenessEntry],
        complianceEvents: [PlanComplianceEvent],
        feedbackEvents: [WorkoutFeedbackEvent],
        trainingBlocks: [TrainingBlock],
        health: HealthSignals,
        externalWorkouts: [ExternalWorkout],
        scheduledName: String?,
        todayWeekday: Int,
        todaysWorkouts: [Workout],
        settings: UserSettings
    ) {
        let recovery = RecoveryEngine.evaluate(
            workouts: finishedWorkouts,
            health: health,
            externalWorkouts: externalWorkouts,
            cardioSessions: Array(cardioSessions.prefix(50)),
            sorenessReports: Array(sorenessReports.prefix(30))
        )
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .distantPast
        let recent = finishedWorkouts.filter { $0.date >= twoWeeksAgo }
        let plan = TodayPlanEngine.generate(
            scheduledName: scheduledName ?? settings.weeklyPlan[todayWeekday],
            recovery: recovery,
            health: health,
            recentWorkouts: recent,
            alreadyTrainedToday: !todaysWorkouts.filter(\.isFinished).isEmpty
                || cardioSessions.contains { Calendar.current.isDateInToday($0.date) },
            hasAnyHistory: !finishedWorkouts.isEmpty,
            complianceEvents: Array(complianceEvents.prefix(14)),
            feedbackEvents: Array(feedbackEvents.prefix(14)),
            currentBlock: TrainingBlockEngine.currentBlock(in: trainingBlocks)
        )
        recoveryResult = recovery
        todayPlan = plan
        MetriclySyncCoordinator.publishAdaptivePlan(recovery: recovery, plan: plan)
    }
}
