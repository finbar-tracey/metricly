import SwiftUI
import HealthKit
import WatchKit

// MARK: - WatchGymView

struct WatchGymView: View {
    @EnvironmentObject var sessionManager: WatchWorkoutSessionManager
    @EnvironmentObject var connectivity:   WatchConnectivityManager

    @State var workoutName  = "Workout"
    @State var exercises: [WatchExerciseRecord] = []
    @State var showingNameEntry = false
    @State var showingAddExercise = false
    @State var showingFinish = false
    @State var showingDiscardConfirm = false
    @State var showingControls = false
    @State var showingFinishPhoneConfirm = false
    @State var startDate: Date?

    var body: some View {
        if sessionManager.isRunning {
            activeView
        } else {
            preWorkoutView
        }
    }

    // MARK: - Actions

    func startWorkout() {
        startDate   = .now
        workoutName = connectivity.todayPlanName.isEmpty
            ? "Workout" : connectivity.todayPlanName

        exercises = connectivity.todayPlannedExercises.map {
            WatchExerciseRecord(name: $0)
        }

        Task {
            await sessionManager.requestAuthorization()
            try? await sessionManager.startSession(
                activityType: .traditionalStrengthTraining,
                isIndoor: true
            )
            sessionManager.publishActiveState(
                startedAt: startDate,
                name: workoutName
            )
        }
    }

    func finishWorkout() {
        let end = Date.now
        let payload = WatchWorkoutPayload(
            id:           UUID(),
            name:         workoutName,
            startDate:    startDate ?? end,
            endDate:      end,
            totalCalories: sessionManager.activeCalories > 0 ? sessionManager.activeCalories : nil,
            avgHeartRate: avgHeartRateForPayload,
            maxHeartRate: sessionManager.maxHeartRate > 0 ? sessionManager.maxHeartRate : nil,
            exercises:    exercises.map { ex in
                WatchExercisePayload(
                    name: ex.name,
                    sets: ex.sets.map { s in
                        WatchSetPayload(reps: s.reps, weightKg: s.weightKg, isWarmUp: s.isWarmUp)
                    }
                )
            }
        )

        Task {
            try? await sessionManager.endSession()
            WatchConnectivityManager.shared.sendWorkout(payload)
        }

        exercises   = []
        startDate   = nil
        showingFinish = false
    }

    func discardWorkout() {
        Task {
            _ = try? await sessionManager.endSession()
        }
        exercises = []
        startDate = nil
        showingFinish = false
        WKInterfaceDevice.current().play(.failure)
    }

    var avgHeartRateForPayload: Double? {
        if sessionManager.averageHeartRate > 0 { return sessionManager.averageHeartRate }
        if sessionManager.heartRate > 0        { return sessionManager.heartRate }
        return nil
    }

    func intensityTint(_ raw: String) -> Color {
        switch raw {
        case "rest":     return .gray
        case "light":    return .blue
        case "moderate": return .green
        case "hard":     return .orange
        default:         return .blue
        }
    }
}
