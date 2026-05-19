import ActivityKit
import Foundation

@MainActor
final class WorkoutActivityManager {
    static let shared = WorkoutActivityManager()

    private var currentActivity: Activity<WorkoutActivityAttributes>?
    private var updateTimer: Timer?

    private init() {}

    func startActivity(workoutName: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = WorkoutActivityAttributes(
            workoutName: workoutName,
            startDate: .now
        )

        let initialState = WorkoutActivityAttributes.ContentState(
            exerciseCount: 0,
            setCount: 0,
            currentExercise: "Getting started...",
            elapsedSeconds: 0
        )

        let content = ActivityContent(state: initialState, staleDate: nil)

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            startUpdateTimer()
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }

    func updateActivity(exerciseCount: Int, setCount: Int, currentExercise: String) {
        guard let activity = currentActivity else { return }

        let elapsed = Int(Date.now.timeIntervalSince(activity.attributes.startDate))

        let state = WorkoutActivityAttributes.ContentState(
            exerciseCount: exerciseCount,
            setCount: setCount,
            currentExercise: currentExercise,
            elapsedSeconds: elapsed
        )

        let content = ActivityContent(state: state, staleDate: nil)

        Task {
            await activity.update(content)
        }
    }

    func endActivity(exerciseCount: Int, setCount: Int) {
        guard let activity = currentActivity else { return }

        stopUpdateTimer()

        let elapsed = Int(Date.now.timeIntervalSince(activity.attributes.startDate))

        let finalState = WorkoutActivityAttributes.ContentState(
            exerciseCount: exerciseCount,
            setCount: setCount,
            currentExercise: "Workout Complete!",
            elapsedSeconds: elapsed
        )

        let content = ActivityContent(state: finalState, staleDate: nil)

        Task {
            await activity.end(content, dismissalPolicy: .after(.now + 300))
            currentActivity = nil
        }
    }

    var isActive: Bool {
        currentActivity != nil
    }

    // MARK: - Cold-launch reconciliation

    /// Reconcile any system-level Live Activities we don't currently track.
    ///
    /// Why this exists: if the app is force-quit (or crashes) mid-workout,
    /// `endActivity` never runs. The Live Activity persists in iOS for up
    /// to 12 hours, sitting on the user's lock screen with frozen data.
    /// On the next launch our singleton's `currentActivity` is nil, so we
    /// can't update or end it without first re-attaching.
    ///
    /// Policy:
    /// - Any activity older than 6 hours → end immediately. No workout
    ///   plausibly runs that long; it's an orphan.
    /// - Activity matching the in-progress workout (same name + start
    ///   date within a few seconds) → re-attach so future updates flow.
    /// - Anything else → end. The user deleted/finished the workout while
    ///   the app was killed; the activity is stale.
    func reconcileOnLaunch(activeWorkoutName: String?, activeWorkoutStartedAt: Date?) {
        let activities = Activity<WorkoutActivityAttributes>.activities
        for activity in activities {
            let age = Date.now.timeIntervalSince(activity.attributes.startDate)
            if age > 6 * 3600 {
                Task { await activity.end(nil, dismissalPolicy: .immediate) }
                continue
            }
            if let name = activeWorkoutName,
               let startedAt = activeWorkoutStartedAt,
               activity.attributes.workoutName == name,
               abs(activity.attributes.startDate.timeIntervalSince(startedAt)) < 5 {
                if currentActivity == nil {
                    currentActivity = activity
                    startUpdateTimer()
                }
            } else {
                Task { await activity.end(nil, dismissalPolicy: .immediate) }
            }
        }
    }

    // MARK: - Timer for elapsed time updates

    private func startUpdateTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let activity = self.currentActivity else { return }
                let elapsed = Int(Date.now.timeIntervalSince(activity.attributes.startDate))
                let state = WorkoutActivityAttributes.ContentState(
                    exerciseCount: activity.content.state.exerciseCount,
                    setCount: activity.content.state.setCount,
                    currentExercise: activity.content.state.currentExercise,
                    elapsedSeconds: elapsed
                )
                let content = ActivityContent(state: state, staleDate: nil)
                await activity.update(content)
            }
        }
    }

    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
}
