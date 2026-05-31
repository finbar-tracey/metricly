import Foundation
import SwiftData

/// Central entry for App Group / widget snapshot writes and today's plan cache.
enum MetriclySyncCoordinator {

    /// Adaptive plan from Home (or any authoritative recompute).
    static func publishAdaptivePlan(recovery: RecoveryResult, plan: TodayPlan) {
        TodayPlanStore.save(plan)
        WidgetDataWriter.update(
            readinessScore: recovery.readinessScore,
            readinessPlanName: plan.intensity == .rest ? "Rest day" : plan.recommendedName
        )
    }

    /// Tab-shell snapshot: streak, weekly progress, scheduled name (foreground / launch).
    static func publishDashboardSnapshot(
        workouts: [Workout],
        cardioSessions: [CardioSession],
        settings: UserSettings
    ) {
        let weekday = Calendar.current.component(.weekday, from: Date())
        let scheduled = settings.weeklyPlan[weekday] ?? ""
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .distantPast
        let activitiesThisWeek = workouts.filter { $0.date >= weekStart }.count
            + cardioSessions.filter { $0.date >= weekStart }.count
        let weeklyCardioKm = cardioSessions
            .filter { $0.date >= weekStart }
            .reduce(0.0) { $0 + $1.distanceMeters } / 1000

        WidgetDataWriter.update(
            streakDays: Workout.currentStreak(from: workouts, cardioSessions: cardioSessions),
            todayWorkoutName: workouts.first(where: { Calendar.current.isDateInToday($0.date) })?.name ?? "",
            weeklyCardioKm: weeklyCardioKm,
            weeklyGoal: settings.weeklyGoal,
            workoutsThisWeek: activitiesThisWeek,
            weeklyCardioGoalKm: settings.weeklyCardioDistanceGoalKm,
            todayScheduledName: scheduled
        )
    }

    /// After finishing a strength workout (partial widget fields; full snapshot on next foreground).
    static func publishAfterWorkoutFinish(workout: Workout, settings: UserSettings) {
        WidgetDataWriter.update(
            todayWorkoutName: workout.name,
            weeklyGoal: settings.weeklyGoal
        )
    }

    /// After saving a completed cardio session.
    static func publishAfterCardioFinish(session: CardioSession, useKm: Bool) {
        WidgetDataWriter.update(
            lastRunPace: session.formattedPace(useKm: useKm),
            lastRunDist: session.formattedDistance(useKm: useKm)
        )
    }

    static func publishWater(todayMl: Double, goalMl: Double) {
        WidgetDataWriter.updateWater(todayMl: todayMl, goalMl: goalMl)
    }

    static func publishCaffeine(
        entries: [(date: Date, milligrams: Double)],
        halfLifeHours: Double,
        dailyLimitMg: Double
    ) {
        WidgetDataWriter.updateCaffeine(
            entries: entries,
            halfLifeHours: halfLifeHours,
            dailyLimitMg: dailyLimitMg
        )
    }

    /// Widget publish + immediate Watch / Live Activity refresh.
    @MainActor
    static func publishAfterWorkoutFinishAndRefresh(
        workout: Workout,
        settings: UserSettings,
        modelContainer: ModelContainer
    ) {
        publishAfterWorkoutFinish(workout: workout, settings: settings)
        AppLifecycleCoordinator.refreshExtensions(modelContainer: modelContainer)
    }

    @MainActor
    static func publishAfterCardioFinishAndRefresh(
        session: CardioSession,
        useKm: Bool,
        modelContainer: ModelContainer
    ) {
        publishAfterCardioFinish(session: session, useKm: useKm)
        AppLifecycleCoordinator.refreshExtensions(modelContainer: modelContainer)
    }
}
