import CoreLocation
import HealthKit

// MARK: - Cardio write

extension HealthKitManager {

    /// Save a cardio session to Apple Health with distance and active calories.
    func saveCardioSession(_ session: CardioSession) async throws {
        guard isAvailable else { return }
        let start = session.start
        let end   = session.end
        guard session.durationSeconds > 0 else { return }

        let config = HKWorkoutConfiguration()
        switch session.type {
        case .outdoorRun:
            config.activityType = .running
            config.locationType = .outdoor
        case .indoorRun:
            config.activityType = .running
            config.locationType = .indoor
        case .outdoorWalk:
            config.activityType = .walking
            config.locationType = .outdoor
        case .indoorWalk:
            config.activityType = .walking
            config.locationType = .indoor
        case .outdoorCycle:
            config.activityType = .cycling
            config.locationType = .outdoor
        }

        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        try await builder.beginCollection(at: start)

        var samples: [HKSample] = []

        if session.distanceMeters > 0 {
            let distType: HKQuantityTypeIdentifier = (session.type == .outdoorCycle)
                ? .distanceCycling : .distanceWalkingRunning
            let distSample = HKQuantitySample(
                type: HKQuantityType(distType),
                quantity: HKQuantity(unit: .meter(), doubleValue: session.distanceMeters),
                start: start, end: end
            )
            samples.append(distSample)
        }

        let kcal = session.caloriesBurned ?? session.estimatedCalories()
        let energySample = HKQuantitySample(
            type: HKQuantityType(.activeEnergyBurned),
            quantity: HKQuantity(unit: .kilocalorie(), doubleValue: kcal),
            start: start, end: end
        )
        samples.append(energySample)

        if let avgHR = session.avgHeartRate, avgHR > 0 {
            let hrUnit  = HKUnit.count().unitDivided(by: .minute())
            let hrSample = HKQuantitySample(
                type: HKQuantityType(.heartRate),
                quantity: HKQuantity(unit: hrUnit, doubleValue: avgHR),
                start: start, end: end
            )
            samples.append(hrSample)
        }

        if !samples.isEmpty { try await builder.addSamples(samples) }
        try await builder.endCollection(at: end)
        try await builder.addMetadata([HKMetadataKeyWorkoutBrandName: session.title])
        let workout = try await builder.finishWorkout()

        if let workout, session.type.usesGPS, !session.routePoints.isEmpty {
            try await saveRoute(for: workout, points: session.routePoints)
        }
    }

    func saveRoute(for workout: HKWorkout, points: [CardioRoutePoint]) async throws {
        let locations: [CLLocation] = points.map { p in
            CLLocation(
                coordinate: CLLocationCoordinate2D(
                    latitude: p.latitude, longitude: p.longitude
                ),
                altitude: p.altitude,
                horizontalAccuracy: kCLLocationAccuracyBest,
                verticalAccuracy:   kCLLocationAccuracyBest,
                course:             -1,
                speed:              -1,
                timestamp:          p.timestamp
            )
        }
        guard !locations.isEmpty else { return }

        let routeBuilder = HKWorkoutRouteBuilder(healthStore: store, device: .local())
        try await routeBuilder.insertRouteData(locations)
        _ = try await routeBuilder.finishRoute(
            with: workout,
            metadata: [HKMetadataKeyWorkoutBrandName: "Metricly"]
        )
    }
}
