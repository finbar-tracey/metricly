import AppIntents
import SwiftData
import Foundation

// MARK: - Start Workout Intent

struct StartWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Workout"
    static var description: IntentDescription = "Creates a new workout in Metricly and opens the app."
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Workout Name")
    var workoutName: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let name = workoutName ?? defaultName()
        let container = try MetriclySchema.makeSharedContainer()
        let context = container.mainContext
        let workout = Workout(name: name, date: .now)
        context.insert(workout)
        try context.save()
        return .result(dialog: "Started \"\(name)\". Open Metricly to add exercises.")
    }

    private func defaultName() -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "Workout – \(f.string(from: .now))"
    }
}

// MARK: - Get Streak Intent

struct GetStreakIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Workout Streak"
    static var description: IntentDescription = "Returns your current consecutive workout streak in Metricly."

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try MetriclySchema.makeSharedContainer()
        let context = container.mainContext
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { !$0.isTemplate },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let workouts = try context.fetch(descriptor)
        let cardio   = try context.fetch(FetchDescriptor<CardioSession>())
        let streak = Workout.currentStreak(from: workouts, cardioSessions: cardio)
        if streak == 0 {
            return .result(dialog: "No active streak yet — log a workout today to start one!")
        } else if streak == 1 {
            return .result(dialog: "You're on a 1-day streak. Keep it going!")
        } else {
            return .result(dialog: "You're on a \(streak)-day streak in Metricly. 🔥 Keep it up!")
        }
    }
}

// MARK: - Get Workout Stats Intent

struct GetWorkoutStatsIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Workout Stats"
    static var description: IntentDescription = "Shows your recent workout statistics from Metricly."

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try MetriclySchema.makeSharedContainer()
        let context = container.mainContext
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { !$0.isTemplate },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let workouts = try context.fetch(descriptor)
        let cardio   = try context.fetch(FetchDescriptor<CardioSession>())
        let total = workouts.count
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let thisWeek = workouts.filter { $0.date >= weekStart }.count + cardio.filter { $0.date >= weekStart }.count
        let streak = Workout.currentStreak(from: workouts, cardioSessions: cardio)
        return .result(dialog: "\(total) total workouts, \(thisWeek) this week, \(streak)-day streak.")
    }
}

// MARK: - Log Body Weight Intent

struct LogBodyWeightIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Body Weight"
    static var description: IntentDescription = "Records your body weight in Metricly."

    @Parameter(title: "Weight in kg")
    var weight: Double

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try MetriclySchema.makeSharedContainer()
        let context = container.mainContext
        context.insert(BodyWeightEntry(date: .now, weight: weight))
        try context.save()
        return .result(dialog: "Logged \(String(format: "%.1f", weight)) kg. Keep it up!")
    }
}

// MARK: - Log Water Intent

struct LogWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Water"
    static var description: IntentDescription = "Adds a water entry to Metricly."

    @Parameter(title: "Amount in ml", default: 250)
    var milliliters: Int

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try MetriclySchema.makeSharedContainer()
        let context = container.mainContext
        context.insert(WaterEntry(date: .now, milliliters: Double(milliliters)))
        try context.save()
        let cups = Double(milliliters) / 250
        return .result(dialog: "Logged \(milliliters) ml of water — that's \(String(format: "%.1f", cups)) cups. Stay hydrated!")
    }
}

// MARK: - Today's Workout Intent

struct GetTodayWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Today's Workout"
    static var description: IntentDescription = "Tells you what workout is scheduled for today in Metricly."
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try MetriclySchema.makeSharedContainer()
        let context = container.mainContext

        let settings = try context.fetch(FetchDescriptor<UserSettings>()).first
        let weekday = Calendar.current.component(.weekday, from: .now)
        let scheduledName = settings?.weeklyPlan[weekday] ?? ""

        let workouts = (try? context.fetch(FetchDescriptor<Workout>())) ?? []
        let cardio = (try? context.fetch(FetchDescriptor<CardioSession>())) ?? []

        // Short-circuit: already trained today.
        let startOfDay = Calendar.current.startOfDay(for: .now)
        if let w = workouts.first(where: { !$0.isTemplate && $0.date >= startOfDay }) {
            return .result(dialog: "You've already trained today — \(w.name). Great work.")
        }

        // Build the adaptive plan via the same engines the home dashboard
        // uses. Siri intents can't reach HealthKit during execution, so we
        // pass empty HealthSignals — the engine's confidence model now
        // takes that into account and won't claim high-confidence anything.
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .distantPast
        let recentWorkouts = workouts.filter { !$0.isTemplate && $0.endTime != nil && $0.date >= twoWeeksAgo }
        let recovery = RecoveryEngine.evaluate(
            workouts: workouts.filter { !$0.isTemplate && $0.endTime != nil },
            health: HealthSignals(),
            cardioSessions: cardio
        )
        let hasAnyHistory = workouts.contains { !$0.isTemplate && $0.endTime != nil }

        let plan = TodayPlanEngine.generate(
            scheduledName: scheduledName.isEmpty ? nil : scheduledName,
            recovery: recovery,
            health: HealthSignals(),
            recentWorkouts: recentWorkouts,
            alreadyTrainedToday: false,
            hasAnyHistory: hasAnyHistory
        )

        // First-time users (no logged history) get a friendly nudge rather
        // than a robotic recommendation the engine can't back up.
        if !hasAnyHistory {
            return .result(dialog: "Log your first workout in Metricly and I'll start recommending what to train.")
        }

        let intensity: String = {
            switch plan.intensity {
            case .rest:     return "today is a rest day"
            case .light:    return "go light today"
            case .moderate: return "moderate intensity"
            case .hard:     return "push hard today"
            }
        }()
        return .result(dialog: "Metricly recommends \(plan.recommendedName) — \(intensity).")
    }
}

// MARK: - App Shortcuts Provider

struct MetriclyShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartWorkoutIntent(),
            phrases: [
                "Start a workout in \(.applicationName)",
                "Begin workout in \(.applicationName)",
                "Log a workout with \(.applicationName)",
                "New workout in \(.applicationName)"
            ],
            shortTitle: "Start Workout",
            systemImageName: "figure.strengthtraining.traditional"
        )
        AppShortcut(
            intent: GetStreakIntent(),
            phrases: [
                "What's my streak in \(.applicationName)",
                "How long is my streak in \(.applicationName)",
                "Check my streak with \(.applicationName)"
            ],
            shortTitle: "My Streak",
            systemImageName: "flame.fill"
        )
        AppShortcut(
            intent: GetTodayWorkoutIntent(),
            phrases: [
                "What's my workout today in \(.applicationName)",
                "What am I training today in \(.applicationName)",
                "Today's workout in \(.applicationName)"
            ],
            shortTitle: "Today's Workout",
            systemImageName: "calendar"
        )
        AppShortcut(
            intent: GetWorkoutStatsIntent(),
            phrases: [
                "Get my stats from \(.applicationName)",
                "Show my workout stats in \(.applicationName)",
                "How many workouts in \(.applicationName)"
            ],
            shortTitle: "Workout Stats",
            systemImageName: "chart.bar"
        )
        AppShortcut(
            intent: LogBodyWeightIntent(),
            phrases: [
                "Log my weight in \(.applicationName)",
                "Record body weight with \(.applicationName)",
                "Track my weight in \(.applicationName)"
            ],
            shortTitle: "Log Weight",
            systemImageName: "scalemass"
        )
        AppShortcut(
            intent: LogWaterIntent(),
            phrases: [
                "Log water in \(.applicationName)",
                "Add water in \(.applicationName)",
                "Track my hydration in \(.applicationName)"
            ],
            shortTitle: "Log Water",
            systemImageName: "drop.fill"
        )
    }
}
