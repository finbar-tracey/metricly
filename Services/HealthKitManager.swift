import HealthKit
import SwiftUI

@MainActor
final class HealthKitManager {
    static let shared = HealthKitManager()
    private let store = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Authorization

    func requestAuthorization() async throws {
        guard isAvailable else { return }

        let typesToShare: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .bodyMass)!
        ]

        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .vo2Max)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]

        try await store.requestAuthorization(toShare: typesToShare, read: typesToRead)
    }

    // MARK: - Steps

    func fetchSteps(for date: Date) async throws -> Double {
        let type = HKQuantityType(.stepCount)
        let interval = Calendar.current.dateInterval(of: .day, for: date)!
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
        let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -days, to: .now)!)
        let end = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: .now)!)
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

    // MARK: - Heart Rate

    func fetchRestingHeartRate(for date: Date) async throws -> Double? {
        let type = HKQuantityType(.restingHeartRate)
        let interval = Calendar.current.dateInterval(of: .day, for: date)!
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
        let interval = Calendar.current.dateInterval(of: .day, for: date)!
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
        let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -days, to: .now)!)
        let end = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: .now)!)
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

    // MARK: - HRV

    func fetchHRV(for date: Date) async throws -> Double? {
        let type = HKQuantityType(.heartRateVariabilitySDNN)
        let interval = Calendar.current.dateInterval(of: .day, for: date)!
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
        let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -days, to: .now)!)
        let end = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: .now)!)
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
        let eveningBefore = calendar.date(bySettingHour: 18, minute: 0, second: 0,
            of: calendar.date(byAdding: .day, value: -1, to: date)!)!
        let noonOfDate = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date)!
        let predicate = HKQuery.predicateForSamples(withStart: eveningBefore, end: noonOfDate)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let samples = try await descriptor.result(for: store)

        var inBed: Date?
        var wakeUp: Date?
        // Collect raw asleep intervals for merging (to deduplicate overlapping sources)
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
                if inBed == nil || sample.startDate < inBed! { inBed = sample.startDate }
                if wakeUp == nil || sample.endDate > wakeUp! { wakeUp = sample.endDate }
            case .awake:
                stages.append(SleepStage(type: .awake, start: sample.startDate, end: sample.endDate))
            default:
                break
            }
        }

        // Merge overlapping intervals to avoid double-counting from multiple sources
        let totalAsleep = mergedDuration(of: asleepIntervals)

        return (totalAsleep / 60, inBed, wakeUp, stages)
    }

    /// Merges overlapping time intervals and returns the total non-overlapping duration in seconds.
    private func mergedDuration(of intervals: [(start: Date, end: Date)]) -> TimeInterval {
        guard !intervals.isEmpty else { return 0 }
        let sorted = intervals.sorted { $0.start < $1.start }
        var merged: [(start: Date, end: Date)] = [sorted[0]]

        for interval in sorted.dropFirst() {
            if interval.start <= merged[merged.count - 1].end {
                // Overlapping — extend the current merged interval
                merged[merged.count - 1].end = max(merged[merged.count - 1].end, interval.end)
            } else {
                merged.append(interval)
            }
        }

        return merged.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }
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

    // MARK: - Active Energy

    func fetchActiveEnergy(for date: Date) async throws -> Double {
        let type = HKQuantityType(.activeEnergyBurned)
        let interval = Calendar.current.dateInterval(of: .day, for: date)!
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

    // MARK: - Write (existing)

    func saveWorkout(name: String, start: Date, end: Date) async throws {
        guard isAvailable else { return }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor

        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        try await builder.beginCollection(at: start)
        try await builder.endCollection(at: end)
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

// MARK: - Sleep Stage Type

struct SleepStage: Identifiable {
    let id = UUID()
    let type: StageType
    let start: Date
    let end: Date

    enum StageType: String {
        case core = "Core"
        case deep = "Deep"
        case rem = "REM"
        case awake = "Awake"
        case unspecified = "Asleep"

        var color: Color {
            switch self {
            case .deep: return .indigo
            case .core: return .blue
            case .rem: return .cyan
            case .awake: return .orange
            case .unspecified: return .blue
            }
        }
    }

    var durationMinutes: Double {
        end.timeIntervalSince(start) / 60
    }
}
