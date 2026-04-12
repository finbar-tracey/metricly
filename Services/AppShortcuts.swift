import AppIntents
import SwiftData
import Foundation

// MARK: - Start Workout Intent

struct StartWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Workout"
    static var description: IntentDescription = "Creates a new workout in Metricly."
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Workout Name")
    var workoutName: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let name = workoutName ?? defaultName()
        return .result(dialog: "Starting \"\(name)\". Open Metricly to add exercises.")
    }

    private func defaultName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "Workout - \(formatter.string(from: .now))"
    }
}

// MARK: - Get Stats Intent

struct GetWorkoutStatsIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Workout Stats"
    static var description: IntentDescription = "Shows your recent workout statistics from Metricly."

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try ModelContainer(for: Workout.self, UserSettings.self, BodyWeightEntry.self, TrainingProgram.self)
        let context = container.mainContext

        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { !$0.isTemplate },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let workouts = try context.fetch(descriptor)

        let total = workouts.count
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let thisWeek = workouts.filter { $0.date >= weekStart }.count

        // Streak
        let workoutDays = Set(workouts.map { calendar.startOfDay(for: $0.date) })
        var streak = 0
        var checkDate = calendar.startOfDay(for: .now)
        if !workoutDays.contains(checkDate),
           let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) {
            checkDate = yesterday
        }
        while workoutDays.contains(checkDate) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }

        return .result(dialog: "You've done \(total) total workouts, \(thisWeek) this week, with a \(streak)-day streak.")
    }
}

// MARK: - Log Body Weight Intent

struct LogBodyWeightIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Body Weight"
    static var description: IntentDescription = "Records your body weight in Metricly."

    @Parameter(title: "Weight (kg)")
    var weight: Double

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try ModelContainer(for: Workout.self, UserSettings.self, BodyWeightEntry.self, TrainingProgram.self)
        let context = container.mainContext

        let entry = BodyWeightEntry(date: .now, weight: weight)
        context.insert(entry)
        try context.save()

        return .result(dialog: "Logged \(String(format: "%.1f", weight)) kg. Keep it up!")
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
                "Log a workout with \(.applicationName)"
            ],
            shortTitle: "Start Workout",
            systemImageName: "figure.strengthtraining.traditional"
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
                "Record body weight with \(.applicationName)"
            ],
            shortTitle: "Log Weight",
            systemImageName: "scalemass"
        )
    }
}
