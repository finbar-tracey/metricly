import Foundation
import HealthKit
import WatchKit

// MARK: - WatchWorkoutSessionManager
//
// Owns the HKWorkoutSession for both gym and cardio workouts.
// A single active session at a time. Publishes live metrics to the UI.

@MainActor
final class WatchWorkoutSessionManager: NSObject, ObservableObject {

    // MARK: - Published live metrics

    @Published var heartRate        : Double  = 0
    @Published var heartRateZone    : HRZone  = .resting
    @Published var activeCalories   : Double  = 0
    @Published var distanceMeters   : Double  = 0
    @Published var elapsedSeconds   : Int     = 0
    @Published var isRunning        : Bool    = false
    @Published var isPaused         : Bool    = false
    @Published var sessionError     : Error?  = nil

    // Peak HR recorded during session
    @Published var maxHeartRate     : Double  = 0

    // MARK: - Private

    private let healthStore = HKHealthStore()
    private var session  : HKWorkoutSession?
    private var builder  : HKLiveWorkoutBuilder?
    private var timer    : Timer?
    private var startDate: Date?

    // Config captured for the current session
    private(set) var activityType : HKWorkoutActivityType = .traditionalStrengthTraining
    private(set) var isIndoor     : Bool = true

    // MARK: - Authorization

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let share: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.heartRate),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceCycling)
        ]
        let read: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceCycling)
        ]
        try? await healthStore.requestAuthorization(toShare: share, read: read)
    }

    // MARK: - Start / Pause / Resume / End

    func startSession(activityType: HKWorkoutActivityType, isIndoor: Bool) async throws {
        guard !isRunning else { return }

        self.activityType = activityType
        self.isIndoor     = isIndoor

        let config = HKWorkoutConfiguration()
        config.activityType = activityType
        config.locationType = isIndoor ? .indoor : .outdoor

        let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: config
        )

        session.delegate = self
        builder.delegate = self

        self.session = session
        self.builder = builder

        session.startActivity(with: .now)
        try await builder.beginCollection(at: .now)

        startDate = .now
        reset()
        isRunning = true
        isPaused  = false
        startElapsedTimer()

        WKInterfaceDevice.current().play(.start)
    }

    func pause() {
        session?.pause()
        timer?.invalidate()
        isPaused = true
        WKInterfaceDevice.current().play(.stop)
    }

    func resume() {
        session?.resume()
        startElapsedTimer()
        isPaused = false
        WKInterfaceDevice.current().play(.start)
    }

    /// Ends the session and returns the saved HKWorkout.
    func endSession() async throws -> HKWorkout? {
        guard let session, let builder else { return nil }
        session.end()
        try await builder.endCollection(at: .now)
        let workout = try await builder.finishWorkout()
        cleanup()
        WKInterfaceDevice.current().play(.success)
        return workout
    }

    // MARK: - Private helpers

    private func reset() {
        heartRate       = 0
        heartRateZone   = .resting
        activeCalories  = 0
        distanceMeters  = 0
        elapsedSeconds  = 0
        maxHeartRate    = 0
    }

    private func cleanup() {
        timer?.invalidate()
        timer    = nil
        session  = nil
        builder  = nil
        startDate = nil
        isRunning = false
        isPaused  = false
    }

    private func startElapsedTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let start = self.startDate else { return }
            Task { @MainActor in
                self.elapsedSeconds = Int(Date.now.timeIntervalSince(start))
            }
        }
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WatchWorkoutSessionManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in
            switch toState {
            case .running:
                self.isRunning = true
                self.isPaused  = false
            case .paused:
                self.isPaused  = true
            case .ended:
                self.isRunning = false
                self.isPaused  = false
            default: break
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in self.sessionError = error }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WatchWorkoutSessionManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        let hrUnit = HKUnit.count().unitDivided(by: .minute())

        var newHR       = 0.0
        var newCal      = 0.0
        var newDist     = 0.0
        var updatedHR   = false

        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            guard let stats = workoutBuilder.statistics(for: quantityType) else { continue }

            switch quantityType {
            case HKQuantityType(.heartRate):
                newHR     = stats.mostRecentQuantity()?.doubleValue(for: hrUnit) ?? 0
                updatedHR = true
            case HKQuantityType(.activeEnergyBurned):
                newCal    = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
            case HKQuantityType(.distanceWalkingRunning),
                 HKQuantityType(.distanceCycling):
                newDist   = stats.sumQuantity()?.doubleValue(for: .meter()) ?? 0
            default: break
            }
        }

        Task { @MainActor in
            if updatedHR && newHR > 0 {
                self.heartRate     = newHR
                self.heartRateZone = HRZone.zone(for: newHR)
                if newHR > self.maxHeartRate { self.maxHeartRate = newHR }
            }
            if newCal  > 0 { self.activeCalories  = newCal  }
            if newDist > 0 { self.distanceMeters   = newDist }
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
