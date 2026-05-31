import HealthKit

// MARK: - Workout write

extension HealthKitManager {

    /// Save a strength workout to Apple Health with estimated active calories.
    func saveStrengthWorkout(_ workout: Workout) async throws {
        guard isAvailable else { return }
        let start = workout.date
        let end   = workout.endTime ?? .now
        guard end > start else { return }

        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor

        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        try await builder.beginCollection(at: start)

        let workingSets = workout.exercises.flatMap(\.sets).filter { !$0.isWarmUp }.count
        let estimatedKcal = max(30.0, Double(workingSets) * 5.0)
        let energyType    = HKQuantityType(.activeEnergyBurned)
        let energySample  = HKQuantitySample(
            type: energyType,
            quantity: HKQuantity(unit: .kilocalorie(), doubleValue: estimatedKcal),
            start: start, end: end
        )
        try await builder.addSamples([energySample])

        try await builder.endCollection(at: end)
        try await builder.addMetadata([HKMetadataKeyWorkoutBrandName: workout.name])
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
