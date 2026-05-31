import SwiftUI
import SwiftData

extension ContentView {
    static var shouldSkipOnboardingForUITests: Bool {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("-skipOnboarding") || args.contains("-UITests")
    }

    func performInitialSetup() {
        if Self.shouldSkipOnboardingForUITests {
            settings.hasSeenOnboarding = true
            showingOnboarding = false
        } else if !settings.hasSeenOnboarding {
            showingOnboarding = true
        }
        seedDemoWorkoutIfRequested()
        // Schedule streak nudges based on saved reminder days
        let reminderDays = settings.reminderDays
        if !reminderDays.isEmpty {
            ReminderManager.scheduleStreakNudges(days: reminderDays)
        }
        // Fill in any missing compliance events for the last ~7 days
        // so the engine's confidence model can see how the user's
        // been responding to its suggestions.
        ComplianceBackfill.run(
            workouts: workouts,
            cardioSessions: cardioSessions,
            existingEvents: complianceEvents,
            in: modelContext
        )
        // Inactivity nudge — 3 days after last logged activity
        let lastWorkout = workouts.first?.date
        let lastCardio  = cardioSessions.first?.date
        if let lastActive = [lastWorkout, lastCardio].compactMap({ $0 }).max() {
            ReminderManager.scheduleInactivityNudge(lastActivityDate: lastActive)
        }
        MetriclySyncCoordinator.publishDashboardSnapshot(
            workouts: workouts,
            cardioSessions: cardioSessions,
            settings: settings
        )
    }

    func handleSceneBecameActive() {
        AppLifecycleCoordinator.refreshWatchAndLiveActivity(modelContainer: modelContext.container)
        // Drop the HealthKit cache so the next read is fresh — user
        // may have completed a workout on the Watch while we were
        // backgrounded, and we don't want to render yesterday's
        // resting HR for the next 5 minutes.
        appServices.healthDataCache.invalidateAll()
        let lastWorkout = workouts.first?.date
        let lastCardio  = cardioSessions.first?.date
        if let lastActive = [lastWorkout, lastCardio].compactMap({ $0 }).max() {
            ReminderManager.scheduleInactivityNudge(lastActivityDate: lastActive)
        }
    }

    func seedDemoWorkoutIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-seedDemoWorkout") else { return }
        let descriptor = FetchDescriptor<Workout>(predicate: #Predicate { !$0.isTemplate && $0.endTime == nil })
        if let existing = try? modelContext.fetch(descriptor), !existing.isEmpty { return }
        let workout = Workout(name: "UITest Push", date: .now)
        workout.startTime = .now
        modelContext.insert(workout)
        modelContext.saveOrLog()
    }
}
