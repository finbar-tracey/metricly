import HealthKit

@MainActor
final class HealthKitManager {
    static let shared = HealthKitManager()
    private let store = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async throws {
        guard isAvailable else { return }

        let typesToShare: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .bodyMass)!
        ]

        let typesToRead: Set<HKObjectType> = []

        try await store.requestAuthorization(toShare: typesToShare, read: typesToRead)
    }

    func saveWorkout(name: String, start: Date, end: Date) async throws {
        guard isAvailable else { return }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor

        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        try await builder.beginCollection(at: start)
        try await builder.endCollection(at: end)

        // Add workout name as metadata
        try await builder.addMetadata([HKMetadataKeyWorkoutBrandName: name])

        try await builder.finishWorkout()
    }

    func saveBodyWeight(_ kg: Double, date: Date) async throws {
        guard isAvailable else { return }
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }

        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg)
        let sample = HKQuantitySample(type: quantityType, quantity: quantity, start: date, end: date)
        try await store.save(sample)
    }
}
