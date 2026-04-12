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
