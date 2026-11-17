import HealthKit

// MARK: - Workout write

extension HealthKitManager {

    /// Save a strength workout to Apple Health with estimated active calories.
    func saveStrengthWorkout(_ workout: Workout) async throws {
        guard isAvailable else { return }
        try await reportingFailure("workout") { try await writeStrengthWorkout(workout) }
    }

    private func writeStrengthWorkout(_ workout: Workout) async throws {
        try requireSharing(HKObjectType.workoutType(), what: "workout")
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
        // Sync identifier makes a retried save replace/ignore rather than
        // create a duplicate HKWorkout.
        let syncID = workout.sourceID?.uuidString ?? "\(Int(start.timeIntervalSince1970))"
        try await builder.addMetadata([
            HKMetadataKeyWorkoutBrandName: workout.name,
            HKMetadataKeySyncIdentifier: "metricly.workout.\(syncID)",
            HKMetadataKeySyncVersion: 1
        ])
        try await builder.finishWorkout()
    }

    func saveBodyWeight(_ kg: Double, date: Date) async throws {
        guard isAvailable else { return }
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }
        try requireSharing(quantityType, what: "body weight")

        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg)
        let sample = HKQuantitySample(type: quantityType, quantity: quantity, start: date, end: date)
        try await reportingFailure("body weight") { try await store.save(sample) }
    }
}
