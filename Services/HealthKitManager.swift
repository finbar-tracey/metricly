import HealthKit

@MainActor
final class HealthKitManager {
    static let shared = HealthKitManager()
    let store = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Authorization

    func requestAuthorization() async throws {
        guard isAvailable else { return }

        let typesToShare: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!
        ]

        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
            HKObjectType.quantityType(forIdentifier: .vo2Max)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.workoutType()
        ]

        try await store.requestAuthorization(toShare: typesToShare, read: typesToRead)
    }

    // MARK: - Write guards

    enum WriteError: LocalizedError {
        case notAuthorized
        var errorDescription: String? { "Apple Health sharing is not enabled for Metricly." }
    }

    /// Throws (after surfacing a banner) when the user has denied sharing
    /// for `type`. `.notDetermined` is allowed through; HealthKit will
    /// prompt or fail on its own.
    func requireSharing(_ type: HKObjectType, what: String) throws {
        if store.authorizationStatus(for: type) == .sharingDenied {
            AppErrorBus.shared.report(message: "Couldn't save \(what) to Apple Health: access is turned off in Settings.")
            throw WriteError.notAuthorized
        }
    }

    /// Run a write, surfacing any failure on the global error bus.
    func reportingFailure<T>(_ what: String, _ op: () async throws -> T) async throws -> T {
        do { return try await op() }
        catch {
            if !(error is WriteError) {
                AppErrorBus.shared.report(message: "Couldn't save \(what) to Apple Health.")
            }
            throw error
        }
    }
}
