import Foundation

/// Point-in-time Home data assembled from SwiftData queries (value handles + derived fields).
struct HomeDashboardSnapshot {
    var templates: [Workout] = []
    var finishedWorkouts: [Workout] = []
    var allWorkouts: [Workout] = []
    var settings: UserSettings = UserSettings()
    var caffeineEntries: [CaffeineEntry] = []
    var waterEntries: [WaterEntry] = []
    var creatineEntries: [CreatineEntry] = []
    var cardioSessions: [CardioSession] = []
    var sorenessReports: [SorenessEntry] = []
    var complianceEvents: [PlanComplianceEvent] = []
    var feedbackEvents: [WorkoutFeedbackEvent] = []
    var trainingBlocks: [TrainingBlock] = []

    var hydration: HydrationSummary {
        HydrationSummary.make(entries: waterEntries, goalMl: settings.dailyWaterGoalMl)
    }

    var creatineTakenToday: Bool {
        creatineEntries.contains { $0.date >= Calendar.current.startOfDay(for: .now) }
    }

    var activitiesThisWeek: Int {
        guard let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start else { return 0 }
        let workoutCount = allWorkouts.filter { $0.date >= weekStart }.count
        let cardioCount = cardioSessions.filter { $0.date >= weekStart }.count
        return workoutCount + cardioCount
    }

    var currentStreak: Int {
        Workout.currentStreak(from: allWorkouts, cardioSessions: Array(cardioSessions.prefix(60)))
    }

    var todaysWorkouts: [Workout] {
        allWorkouts.filter { $0.date >= Calendar.current.startOfDay(for: .now) }
    }

    var todayTotalSets: Int {
        todaysWorkouts.reduce(0) { $0 + $1.exercises.reduce(0) { $0 + $1.sets.filter { !$0.isWarmUp }.count } }
    }

    var todayTotalVolumeKg: Double {
        todaysWorkouts.reduce(0.0) { $0 + $1.totalVolumeKg() }
    }

    var inProgressWorkout: Workout? {
        allWorkouts.first { !$0.isFinished }
    }

    var todayWeekday: Int {
        Calendar.current.component(.weekday, from: .now)
    }

    var averageRating: Double? {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .distantPast
        let rated = allWorkouts.filter { $0.date >= weekAgo && ($0.rating ?? 0) > 0 }
        guard !rated.isEmpty else { return nil }
        return Double(rated.compactMap(\.rating).reduce(0, +)) / Double(rated.count)
    }

    static func build(
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
    ) -> HomeDashboardSnapshot {
        HomeDashboardSnapshot(
            templates: templates,
            finishedWorkouts: finishedWorkouts,
            allWorkouts: allWorkouts,
            settings: settingsArray.first ?? UserSettings(),
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
}
