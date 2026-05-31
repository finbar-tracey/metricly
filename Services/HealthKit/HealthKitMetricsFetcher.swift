import HealthKit

// MARK: - Metrics fetch

extension HealthKitManager {

    // MARK: - Steps

    func fetchSteps(for date: Date) async throws -> Double {
        let type = HKQuantityType(.stepCount)
        let interval = Calendar.current.healthKitDayInterval(for: date)
        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: predicate),
            options: .cumulativeSum
        )
        let result = try await descriptor.result(for: store)
        return result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
    }

    func fetchDailySteps(days: Int) async throws -> [(date: Date, steps: Double)] {
        let type = HKQuantityType(.stepCount)
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: calendar.healthKitAdding(.day, value: -days, to: .now))
        let end = calendar.startOfDay(for: calendar.healthKitAdding(.day, value: 1, to: .now))
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: predicate),
            options: .cumulativeSum,
            anchorDate: start,
            intervalComponents: DateComponents(day: 1)
        )
        let collection = try await descriptor.result(for: store)
        var results: [(date: Date, steps: Double)] = []
        collection.enumerateStatistics(from: start, to: end) { statistics, _ in
            let steps = statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0
            results.append((statistics.startDate, steps))
        }
        return results
    }

    func fetchHourlySteps(for date: Date) async throws -> [(hour: Int, steps: Double)] {
        let type = HKQuantityType(.stepCount)
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.healthKitAdding(.day, value: 1, to: start)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: predicate),
            options: .cumulativeSum,
            anchorDate: start,
            intervalComponents: DateComponents(hour: 1)
        )
        let collection = try await descriptor.result(for: store)
        var results: [(hour: Int, steps: Double)] = []
        collection.enumerateStatistics(from: start, to: end) { stats, _ in
            let hour = calendar.component(.hour, from: stats.startDate)
            let steps = stats.sumQuantity()?.doubleValue(for: .count()) ?? 0
            results.append((hour, steps))
        }
        return results
    }

    func fetchDistance(for date: Date) async throws -> Double {
        let type = HKQuantityType(.distanceWalkingRunning)
        let interval = Calendar.current.healthKitDayInterval(for: date)
        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: predicate),
            options: .cumulativeSum
        )
        let result = try await descriptor.result(for: store)
        return result?.sumQuantity()?.doubleValue(for: .meterUnit(with: .kilo)) ?? 0
    }

    func fetchDailyDistance(days: Int) async throws -> [(date: Date, km: Double)] {
        let type = HKQuantityType(.distanceWalkingRunning)
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: calendar.healthKitAdding(.day, value: -days, to: .now))
        let end = calendar.startOfDay(for: calendar.healthKitAdding(.day, value: 1, to: .now))
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: predicate),
            options: .cumulativeSum,
            anchorDate: start,
            intervalComponents: DateComponents(day: 1)
        )
        let collection = try await descriptor.result(for: store)
        var results: [(date: Date, km: Double)] = []
        collection.enumerateStatistics(from: start, to: end) { stats, _ in
            let km = stats.sumQuantity()?.doubleValue(for: .meterUnit(with: .kilo)) ?? 0
            results.append((stats.startDate, km))
        }
        return results
    }

    func fetchDailyActiveEnergy(days: Int) async throws -> [(date: Date, kcal: Double)] {
        let type = HKQuantityType(.activeEnergyBurned)
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: calendar.healthKitAdding(.day, value: -days, to: .now))
        let end = calendar.startOfDay(for: calendar.healthKitAdding(.day, value: 1, to: .now))
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: predicate),
            options: .cumulativeSum,
            anchorDate: start,
            intervalComponents: DateComponents(day: 1)
        )
        let collection = try await descriptor.result(for: store)
        var results: [(date: Date, kcal: Double)] = []
        collection.enumerateStatistics(from: start, to: end) { stats, _ in
            let kcal = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
            results.append((stats.startDate, kcal))
        }
        return results
    }

    // MARK: - Heart Rate

    func fetchRestingHeartRate(for date: Date) async throws -> Double? {
        let type = HKQuantityType(.restingHeartRate)
        let interval = Calendar.current.healthKitDayInterval(for: date)
        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end)
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )
        let samples = try await descriptor.result(for: store)
        return samples.first?.quantity.doubleValue(for: bpmUnit)
    }

    func fetchHeartRateStats(for date: Date) async throws -> (min: Double, max: Double, avg: Double)? {
        let type = HKQuantityType(.heartRate)
        let interval = Calendar.current.healthKitDayInterval(for: date)
        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end)
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: predicate),
            options: [.discreteMin, .discreteMax, .discreteAverage]
        )
        guard let result = try await descriptor.result(for: store),
              let min = result.minimumQuantity()?.doubleValue(for: bpmUnit),
              let max = result.maximumQuantity()?.doubleValue(for: bpmUnit),
              let avg = result.averageQuantity()?.doubleValue(for: bpmUnit) else {
            return nil
        }
        return (min, max, avg)
    }

    func fetchDailyRestingHeartRate(days: Int) async throws -> [(date: Date, bpm: Double)] {
        let type = HKQuantityType(.restingHeartRate)
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: calendar.healthKitAdding(.day, value: -days, to: .now))
        let end = calendar.startOfDay(for: calendar.healthKitAdding(.day, value: 1, to: .now))
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: predicate),
            options: .discreteAverage,
            anchorDate: start,
            intervalComponents: DateComponents(day: 1)
        )
        let collection = try await descriptor.result(for: store)
        var results: [(date: Date, bpm: Double)] = []
        collection.enumerateStatistics(from: start, to: end) { stats, _ in
            if let avg = stats.averageQuantity()?.doubleValue(for: bpmUnit) {
                results.append((stats.startDate, avg))
            }
        }
        return results
    }

    func fetchDailyHeartRateRange(days: Int) async throws -> [(date: Date, min: Double, max: Double)] {
        let type = HKQuantityType(.heartRate)
        let calendar = Calendar.current
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        var results: [(date: Date, min: Double, max: Double)] = []
        for offset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: .now)) else { continue }
            let interval = calendar.healthKitDayInterval(for: date)
            let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end)
            let descriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: type, predicate: predicate),
                options: [.discreteMin, .discreteMax]
            )
            if let result = try await descriptor.result(for: store),
               let minVal = result.minimumQuantity()?.doubleValue(for: bpmUnit),
               let maxVal = result.maximumQuantity()?.doubleValue(for: bpmUnit) {
                results.append((date, minVal, maxVal))
            }
        }
        return results.reversed()
    }

    // MARK: - HRV

    func fetchHRV(for date: Date) async throws -> Double? {
        let type = HKQuantityType(.heartRateVariabilitySDNN)
        let interval = Calendar.current.healthKitDayInterval(for: date)
        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )
        let samples = try await descriptor.result(for: store)
        return samples.first?.quantity.doubleValue(for: .secondUnit(with: .milli))
    }

    func fetchDailyHRV(days: Int) async throws -> [(date: Date, ms: Double)] {
        let type = HKQuantityType(.heartRateVariabilitySDNN)
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: calendar.healthKitAdding(.day, value: -days, to: .now))
        let end = calendar.startOfDay(for: calendar.healthKitAdding(.day, value: 1, to: .now))
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: predicate),
            options: .discreteAverage,
            anchorDate: start,
            intervalComponents: DateComponents(day: 1)
        )
        let collection = try await descriptor.result(for: store)
        var results: [(date: Date, ms: Double)] = []
        collection.enumerateStatistics(from: start, to: end) { stats, _ in
            if let avg = stats.averageQuantity()?.doubleValue(for: .secondUnit(with: .milli)) {
                results.append((stats.startDate, avg))
            }
        }
        return results
    }

    // MARK: - Sleep

    func fetchSleep(for date: Date) async throws -> (totalMinutes: Double, inBed: Date?, wakeUp: Date?, stages: [SleepStage]) {
        let type = HKCategoryType(.sleepAnalysis)
        let calendar = Calendar.current
        let yesterday = calendar.healthKitAdding(.day, value: -1, to: date)
        let eveningBefore = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: yesterday)
            ?? yesterday
        let noonOfDate = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
        let predicate = HKQuery.predicateForSamples(withStart: eveningBefore, end: noonOfDate)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let samples = try await descriptor.result(for: store)

        var inBed: Date?
        var wakeUp: Date?
        var asleepIntervals: [(start: Date, end: Date)] = []
        var stages: [SleepStage] = []

        for sample in samples {
            let value = HKCategoryValueSleepAnalysis(rawValue: sample.value)

            switch value {
            case .asleepCore:
                asleepIntervals.append((sample.startDate, sample.endDate))
                stages.append(SleepStage(type: .core, start: sample.startDate, end: sample.endDate))
            case .asleepDeep:
                asleepIntervals.append((sample.startDate, sample.endDate))
                stages.append(SleepStage(type: .deep, start: sample.startDate, end: sample.endDate))
            case .asleepREM:
                asleepIntervals.append((sample.startDate, sample.endDate))
                stages.append(SleepStage(type: .rem, start: sample.startDate, end: sample.endDate))
            case .asleepUnspecified:
                asleepIntervals.append((sample.startDate, sample.endDate))
                stages.append(SleepStage(type: .unspecified, start: sample.startDate, end: sample.endDate))
            case .inBed:
                inBed = inBed.map { min($0, sample.startDate) } ?? sample.startDate
                wakeUp = wakeUp.map { max($0, sample.endDate) } ?? sample.endDate
            case .awake:
                stages.append(SleepStage(type: .awake, start: sample.startDate, end: sample.endDate))
            default:
                break
            }
        }

        let totalAsleep = HealthKitSleepIntervalMerge.mergedDuration(of: asleepIntervals)

        return (totalAsleep / 60, inBed, wakeUp, stages)
    }

    func fetchDailySleep(days: Int) async throws -> [(date: Date, minutes: Double)] {
        var results: [(date: Date, minutes: Double)] = []
        let calendar = Calendar.current
        for offset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: .now)) else { continue }
            let sleep = try await fetchSleep(for: date)
            if sleep.totalMinutes > 0 {
                results.append((date, sleep.totalMinutes))
            }
        }
        return results.reversed()
    }

    func fetchDailySleepDetailed(days: Int) async throws -> [DailySleepDetail] {
        var results: [DailySleepDetail] = []
        let calendar = Calendar.current
        for offset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: .now)) else { continue }
            let sleep = try await fetchSleep(for: date)
            if sleep.totalMinutes > 0 {
                results.append(DailySleepDetail(
                    date: date,
                    totalMinutes: sleep.totalMinutes,
                    inBed: sleep.inBed,
                    wakeUp: sleep.wakeUp,
                    stages: sleep.stages
                ))
            }
        }
        return results.reversed()
    }

    // MARK: - Active Energy

    func fetchActiveEnergy(for date: Date) async throws -> Double {
        let type = HKQuantityType(.activeEnergyBurned)
        let interval = Calendar.current.healthKitDayInterval(for: date)
        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: predicate),
            options: .cumulativeSum
        )
        let result = try await descriptor.result(for: store)
        return result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
    }

    // MARK: - VO2 Max

    func fetchLatestVO2Max() async throws -> Double? {
        let type = HKQuantityType(.vo2Max)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )
        let samples = try await descriptor.result(for: store)
        let unit = HKUnit.literUnit(with: .milli)
            .unitDivided(by: .gramUnit(with: .kilo))
            .unitDivided(by: .minute())
        return samples.first?.quantity.doubleValue(for: unit)
    }

    // MARK: - External Workouts

    func fetchExternalWorkouts(days: Int) async throws -> [ExternalWorkout] {
        guard isAvailable else { return [] }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: calendar.healthKitAdding(.day, value: -days, to: .now))
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)]
        )

        let samples = try await descriptor.result(for: store)

        return samples.map { workout in
            let calories = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
                .sumQuantity()?.doubleValue(for: .kilocalorie())
            let distance = workout.statistics(for: HKQuantityType(.distanceWalkingRunning))?
                .sumQuantity()?.doubleValue(for: .meter())
                ?? workout.statistics(for: HKQuantityType(.distanceCycling))?
                .sumQuantity()?.doubleValue(for: .meter())

            return ExternalWorkout(
                id: workout.uuid,
                workoutType: workout.workoutActivityType,
                startDate: workout.startDate,
                endDate: workout.endDate,
                duration: workout.duration,
                totalCalories: calories,
                totalDistance: distance,
                sourceName: workout.sourceRevision.source.name
            )
        }
    }
}
