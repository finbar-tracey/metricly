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
        do {
            let container = try MetriclySchema.makeSharedContainer()
            let context = container.mainContext
            let workout = Workout(name: name, date: .now)
            context.insert(workout)
            try context.save()
        } catch {
            return .result(dialog: "I couldn't start that workout right now — try opening Metricly directly.")
        }
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

// MARK: - Intent validators
//
// Extracted from `LogBodyWeightIntent.perform()` etc. so the bounds + the
// rejection-message wording have a single source of truth that's testable
// without instantiating the AppIntents framework. Each intent's perform()
// just consults these.

nonisolated enum IntentValidators {
    nonisolated enum Result: Equatable, Sendable {
        case ok
        case invalid(message: String)
    }

    /// Body-weight bounds: 20–500 kg. Covers the plausible adult range;
    /// anything outside is almost certainly a parse or unit mistake.
    static let bodyWeightRangeKg: ClosedRange<Double> = 20...500

    static func bodyWeight(_ kg: Double) -> Result {
        guard bodyWeightRangeKg.contains(kg) else {
            return .invalid(message: "That doesn't look right — \(String(format: "%.1f", kg)) kg is outside the range I can log. Try a value between \(Int(bodyWeightRangeKg.lowerBound)) and \(Int(bodyWeightRangeKg.upperBound)) kg.")
        }
        return .ok
    }

    /// Water bounds: 1–5000 ml per entry.
    static let waterRangeMl: ClosedRange<Int> = 1...5000

    static func water(_ ml: Int) -> Result {
        guard waterRangeMl.contains(ml) else {
            return .invalid(message: "I can only log between \(waterRangeMl.lowerBound) and \(waterRangeMl.upperBound) ml at a time — \(ml) ml is outside that range.")
        }
        return .ok
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
        // Reject implausible inputs before they corrupt every weight chart
        // and goal in the app — bounds + wording live in IntentValidators
        // so the rejection message is testable without AppIntents wiring.
        if case .invalid(let message) = IntentValidators.bodyWeight(weight) {
            return .result(dialog: IntentDialog(stringLiteral: message))
        }
        do {
            let container = try MetriclySchema.makeSharedContainer()
            let context = container.mainContext
            context.insert(BodyWeightEntry(date: .now, weight: weight))
            try context.save()
        } catch {
            return .result(dialog: "I couldn't save that weight just now — please try again from the app.")
        }
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
        if case .invalid(let message) = IntentValidators.water(milliliters) {
            return .result(dialog: IntentDialog(stringLiteral: message))
        }
        do {
            let container = try MetriclySchema.makeSharedContainer()
            let context = container.mainContext
            context.insert(WaterEntry(date: .now, milliliters: Double(milliliters)))
            try context.save()
        } catch {
            return .result(dialog: "I couldn't save that water entry just now — please try again from the app.")
        }
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

// MARK: - Start Today's Workout Intent
//
// Sibling to `StartWorkoutIntent` (which creates a generic blank
// workout). This one is the "the user actually wants to *do* today's
// adaptive recommendation" path: it builds the same TodayPlan the
// home dashboard does, finds the matching template, copies its
// exercises into a fresh workout, applies the safe plan adjustments
// (avoid-group pruning, light-day trailing-set trim), publishes the
// active state to the watch, and opens the app.
//
// Two intents instead of a single one because the value proposition
// differs: "Start a workout" is a low-friction generic shortcut;
// "Start today's Metricly workout" is the high-conviction Action
// Button / Siri default that surfaces the adaptive feature without
// the user having to open the app first.

struct StartTodayWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Today's Workout"
    static var description: IntentDescription = "Starts today's adaptive workout — the engine's recommendation with plan adjustments applied."
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container: ModelContainer
        do {
            container = try MetriclySchema.makeSharedContainer()
        } catch {
            return .result(dialog: "I couldn't start today's workout right now — try opening Metricly directly.")
        }
        let context = container.mainContext

        // Already trained today? Don't start a duplicate; surface the
        // existing workout's name instead so Siri's response makes sense.
        let startOfDay = Calendar.current.startOfDay(for: .now)
        let allWorkouts = (try? context.fetch(FetchDescriptor<Workout>())) ?? []
        if let existing = allWorkouts.first(where: {
            !$0.isTemplate && $0.date >= startOfDay
        }) {
            return .result(dialog: "You've already started \"\(existing.name)\" today.")
        }

        // Build the same plan the home dashboard does. Same caveat as
        // GetTodayWorkoutIntent: Siri intents can't reach HealthKit
        // during execution, so we pass empty HealthSignals and accept
        // the engine's confidence downgrade.
        let settings = try? context.fetch(FetchDescriptor<UserSettings>()).first
        let weekday = Calendar.current.component(.weekday, from: .now)
        let scheduledName = settings?.weeklyPlan[weekday] ?? ""
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .distantPast
        let recentWorkouts = allWorkouts.filter { !$0.isTemplate && $0.endTime != nil && $0.date >= twoWeeksAgo }
        let cardio = (try? context.fetch(FetchDescriptor<CardioSession>())) ?? []
        let recovery = RecoveryEngine.evaluate(
            workouts: allWorkouts.filter { !$0.isTemplate && $0.endTime != nil },
            health: HealthSignals(),
            cardioSessions: cardio
        )
        let hasAnyHistory = allWorkouts.contains { !$0.isTemplate && $0.endTime != nil }
        let plan = TodayPlanEngine.generate(
            scheduledName: scheduledName.isEmpty ? nil : scheduledName,
            recovery: recovery,
            health: HealthSignals(),
            recentWorkouts: recentWorkouts,
            alreadyTrainedToday: false,
            hasAnyHistory: hasAnyHistory
        )

        // No history → no recommendation worth starting; nudge the
        // user to log a baseline session first.
        if !hasAnyHistory {
            return .result(dialog: "Log your first workout in Metricly so I can start recommending what to train.")
        }

        // The engine says rest. Don't kick off a session — surface why
        // and let the user decide whether to long-press past it from
        // the home Quick Start path.
        if plan.intensity == .rest {
            return .result(dialog: "Metricly recommends rest today. Open the app if you want to override.")
        }

        // Find a template matching the plan's recommended name (case-
        // insensitive — matches the home dashboard's Quick Start path).
        let templates = allWorkouts.filter { $0.isTemplate }
        let template = templates.first {
            $0.name.localizedCaseInsensitiveCompare(plan.recommendedName) == .orderedSame
        }

        let workout = Workout(name: plan.recommendedName, date: .now)
        context.insert(workout)
        if let template {
            workout.copyExercises(from: template.exercises, into: context)
        }
        // Apply the plan: drop avoid-group exercises (no logged sets),
        // trim the trailing blank set on light days. Same call the home
        // Quick Start uses; same safety rules.
        if !workout.exercises.isEmpty {
            TodayPlanApply.apply(plan: plan, to: workout, in: context)
        }
        do {
            try context.save()
        } catch {
            return .result(dialog: "I created the workout but couldn't save it — open Metricly to retry.")
        }

        // Publish to the watch so the complication and any face widgets
        // flip to "In Progress · <name>" without waiting for the next
        // scheduled timeline reload.
        PhoneConnectivityManager.shared.publishActiveWorkout(
            name: workout.name,
            startedAt: workout.date
        )

        return .result(dialog: "Started \(plan.recommendedName). Opening Metricly.")
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
            intent: StartTodayWorkoutIntent(),
            phrases: [
                "Start today's workout in \(.applicationName)",
                "Start my workout in \(.applicationName)",
                "Begin today's workout with \(.applicationName)",
                "Start the recommended workout in \(.applicationName)"
            ],
            shortTitle: "Start Today's Workout",
            systemImageName: "play.fill"
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
