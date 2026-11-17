import Foundation
import HealthKit
import SwiftUI

/// Drop-in caching layer over `HealthKitManager`. Mirrors every public
/// fetch method on the manager so views can switch by changing the
/// receiver only — no other call-site changes.
///
/// ### Why this exists
/// Open Home, then Health, then Heart Rate detail — the old code fired
/// three separate HealthKit queries for the same resting HR even though
/// none of the underlying data could have changed in those few hundred
/// ms. HealthKit isn't free; on Watch it costs battery, on iPhone it
/// adds visible latency.
///
/// The cache holds each result for 5 minutes. When the app foregrounds
/// (`scenePhase == .active`) the whole cache is dropped so the user sees
/// fresh data after returning from elsewhere.
///
/// ### Migration
/// Old:
/// ```swift
/// let steps = try await HealthKitManager.shared.fetchSteps(for: date)
/// ```
/// New:
/// ```swift
/// let steps = try await HealthDataCache.shared.fetchSteps(for: date)
/// ```
/// The two methods have identical signatures — only the receiver changes.
@MainActor
final class HealthDataCache {

    static let shared = HealthDataCache()

    /// Each entry expires after this many seconds. Five minutes is the
    /// sweet spot: long enough that drill-down navigation reuses cached
    /// data, short enough that a user who logs a workout and immediately
    /// checks the dashboard sees the new value (the foreground hook
    /// invalidates anyway).
    static let ttl: TimeInterval = 5 * 60

    private let store = HealthKitManager.shared

    // MARK: - Backing stores
    //
    // Per-method dictionaries keep the value types honest — no `Any`,
    // no runtime casts. Each key is normalised so equivalent calls hit
    // the cache (e.g. fetchSteps for 14:00 and 17:00 same-day collapse
    // to the same `startOfDay`-keyed entry).

    private struct Entry<T> {
        let value: T
        let expiresAt: Date
        var isFresh: Bool { expiresAt > .now }
    }

    private var stepsByDay:            [Date: Entry<Double>] = [:]
    private var hourlyStepsByDay:      [Date: Entry<[(hour: Int, steps: Double)]>] = [:]
    private var distanceByDay:         [Date: Entry<Double>] = [:]
    private var activeEnergyByDay:     [Date: Entry<Double>] = [:]
    private var restingHRByDay:        [Date: Entry<Double?>] = [:]
    private var heartRateStatsByDay:   [Date: Entry<(min: Double, max: Double, avg: Double)?>] = [:]
    private var hrvByDay:              [Date: Entry<Double?>] = [:]
    private var sleepByDay:            [Date: Entry<(totalMinutes: Double, inBed: Date?, wakeUp: Date?, stages: [SleepStage])>] = [:]
    private var activeEnergyTodayByDay: [Date: Entry<Double>] = [:]

    private var dailyStepsByDays:        [Int: Entry<[(date: Date, steps: Double)]>] = [:]
    private var dailyDistanceByDays:     [Int: Entry<[(date: Date, km: Double)]>] = [:]
    private var dailyActiveEnergyByDays: [Int: Entry<[(date: Date, kcal: Double)]>] = [:]
    private var dailyRestingHRByDays:    [Int: Entry<[(date: Date, bpm: Double)]>] = [:]
    private var dailyHRRangeByDays:      [Int: Entry<[(date: Date, min: Double, max: Double)]>] = [:]
    private var dailyHRVByDays:          [Int: Entry<[(date: Date, ms: Double)]>] = [:]
    private var dailySleepByDays:        [Int: Entry<[(date: Date, minutes: Double)]>] = [:]
    private var dailySleepDetailedByDays: [Int: Entry<[DailySleepDetail]>] = [:]
    private var externalWorkoutsByDays:  [Int: Entry<[ExternalWorkout]>] = [:]

    private var latestVO2Max: Entry<Double?>?

    // MARK: - Invalidation

    /// Drop every cached value. Called on `scenePhase == .active` so the
    /// app re-fetches when the user returns from background — they may
    /// have completed a workout on the Watch while we were suspended.
    func invalidateAll() {
        stepsByDay.removeAll()
        hourlyStepsByDay.removeAll()
        distanceByDay.removeAll()
        activeEnergyByDay.removeAll()
        restingHRByDay.removeAll()
        heartRateStatsByDay.removeAll()
        hrvByDay.removeAll()
        sleepByDay.removeAll()
        activeEnergyTodayByDay.removeAll()

        dailyStepsByDays.removeAll()
        dailyDistanceByDays.removeAll()
        dailyActiveEnergyByDays.removeAll()
        dailyRestingHRByDays.removeAll()
        dailyHRRangeByDays.removeAll()
        dailyHRVByDays.removeAll()
        dailySleepByDays.removeAll()
        dailySleepDetailedByDays.removeAll()
        externalWorkoutsByDays.removeAll()

        latestVO2Max = nil
    }

    // MARK: - Pass-through (no caching needed)

    var isAvailable: Bool { store.isAvailable }
    func requestAuthorization() async throws { try await store.requestAuthorization() }
    func saveStrengthWorkout(_ w: Workout) async throws { try await store.saveStrengthWorkout(w) }
    func saveCardioSession(_ s: CardioSession) async throws { try await store.saveCardioSession(s) }
    func saveBodyWeight(_ kg: Double, date: Date) async throws { try await store.saveBodyWeight(kg, date: date) }

    // MARK: - Steps

    func fetchSteps(for date: Date) async throws -> Double {
        let key = Calendar.current.startOfDay(for: date)
        if let entry = stepsByDay[key], entry.isFresh { return entry.value }
        let value = try await coalesce("fetchSteps:\(date)") { try await self.store.fetchSteps(for: date) }
        stepsByDay[key] = makeEntry(value)
        return value
    }

    func fetchDailySteps(days: Int) async throws -> [(date: Date, steps: Double)] {
        if let entry = dailyStepsByDays[days], entry.isFresh { return entry.value }
        let value = try await coalesce("fetchDailySteps:\(days)") { try await self.store.fetchDailySteps(days: days) }
        dailyStepsByDays[days] = makeEntry(value)
        return value
    }

    func fetchHourlySteps(for date: Date) async throws -> [(hour: Int, steps: Double)] {
        let key = Calendar.current.startOfDay(for: date)
        if let entry = hourlyStepsByDay[key], entry.isFresh { return entry.value }
        let value = try await coalesce("fetchHourlySteps:\(date)") { try await self.store.fetchHourlySteps(for: date) }
        hourlyStepsByDay[key] = makeEntry(value)
        return value
    }

    // MARK: - Distance

    func fetchDistance(for date: Date) async throws -> Double {
        let key = Calendar.current.startOfDay(for: date)
        if let entry = distanceByDay[key], entry.isFresh { return entry.value }
        let value = try await coalesce("fetchDistance:\(date)") { try await self.store.fetchDistance(for: date) }
        distanceByDay[key] = makeEntry(value)
        return value
    }

    func fetchDailyDistance(days: Int) async throws -> [(date: Date, km: Double)] {
        if let entry = dailyDistanceByDays[days], entry.isFresh { return entry.value }
        let value = try await coalesce("fetchDailyDistance:\(days)") { try await self.store.fetchDailyDistance(days: days) }
        dailyDistanceByDays[days] = makeEntry(value)
        return value
    }

    // MARK: - Energy

    func fetchActiveEnergy(for date: Date) async throws -> Double {
        let key = Calendar.current.startOfDay(for: date)
        if let entry = activeEnergyByDay[key], entry.isFresh { return entry.value }
        let value = try await coalesce("fetchActiveEnergy:\(date)") { try await self.store.fetchActiveEnergy(for: date) }
        activeEnergyByDay[key] = makeEntry(value)
        return value
    }

    func fetchDailyActiveEnergy(days: Int) async throws -> [(date: Date, kcal: Double)] {
        if let entry = dailyActiveEnergyByDays[days], entry.isFresh { return entry.value }
        let value = try await coalesce("fetchDailyActiveEnergy:\(days)") { try await self.store.fetchDailyActiveEnergy(days: days) }
        dailyActiveEnergyByDays[days] = makeEntry(value)
        return value
    }

    // MARK: - Heart rate

    func fetchRestingHeartRate(for date: Date) async throws -> Double? {
        let key = Calendar.current.startOfDay(for: date)
        if let entry = restingHRByDay[key], entry.isFresh { return entry.value }
        let value = try await coalesce("fetchRestingHeartRate:\(date)") { try await self.store.fetchRestingHeartRate(for: date) }
        restingHRByDay[key] = makeEntry(value)
        return value
    }

    func fetchHeartRateStats(for date: Date) async throws -> (min: Double, max: Double, avg: Double)? {
        let key = Calendar.current.startOfDay(for: date)
        if let entry = heartRateStatsByDay[key], entry.isFresh { return entry.value }
        let value = try await coalesce("fetchHeartRateStats:\(date)") { try await self.store.fetchHeartRateStats(for: date) }
        heartRateStatsByDay[key] = makeEntry(value)
        return value
    }

    func fetchDailyRestingHeartRate(days: Int) async throws -> [(date: Date, bpm: Double)] {
        if let entry = dailyRestingHRByDays[days], entry.isFresh { return entry.value }
        let value = try await coalesce("fetchDailyRestingHeartRate:\(days)") { try await self.store.fetchDailyRestingHeartRate(days: days) }
        dailyRestingHRByDays[days] = makeEntry(value)
        return value
    }

    func fetchDailyHeartRateRange(days: Int) async throws -> [(date: Date, min: Double, max: Double)] {
        if let entry = dailyHRRangeByDays[days], entry.isFresh { return entry.value }
        let value = try await coalesce("fetchDailyHeartRateRange:\(days)") { try await self.store.fetchDailyHeartRateRange(days: days) }
        dailyHRRangeByDays[days] = makeEntry(value)
        return value
    }

    // MARK: - HRV

    func fetchHRV(for date: Date) async throws -> Double? {
        let key = Calendar.current.startOfDay(for: date)
        if let entry = hrvByDay[key], entry.isFresh { return entry.value }
        let value = try await coalesce("fetchHRV:\(date)") { try await self.store.fetchHRV(for: date) }
        hrvByDay[key] = makeEntry(value)
        return value
    }

    func fetchDailyHRV(days: Int) async throws -> [(date: Date, ms: Double)] {
        if let entry = dailyHRVByDays[days], entry.isFresh { return entry.value }
        let value = try await coalesce("fetchDailyHRV:\(days)") { try await self.store.fetchDailyHRV(days: days) }
        dailyHRVByDays[days] = makeEntry(value)
        return value
    }

    // MARK: - Sleep

    func fetchSleep(for date: Date) async throws -> (totalMinutes: Double, inBed: Date?, wakeUp: Date?, stages: [SleepStage]) {
        let key = Calendar.current.startOfDay(for: date)
        if let entry = sleepByDay[key], entry.isFresh { return entry.value }
        let value = try await coalesce("fetchSleep:\(date)") { try await self.store.fetchSleep(for: date) }
        // A tuple isn't recognised by `isEmptyValue`; 0 minutes means no data yet.
        sleepByDay[key] = makeEntry(value, isEmpty: value.totalMinutes == 0)
        return value
    }

    func fetchDailySleep(days: Int) async throws -> [(date: Date, minutes: Double)] {
        if let entry = dailySleepByDays[days], entry.isFresh { return entry.value }
        let value = try await coalesce("fetchDailySleep:\(days)") { try await self.store.fetchDailySleep(days: days) }
        dailySleepByDays[days] = makeEntry(value)
        return value
    }

    func fetchDailySleepDetailed(days: Int) async throws -> [DailySleepDetail] {
        if let entry = dailySleepDetailedByDays[days], entry.isFresh { return entry.value }
        let value = try await coalesce("fetchDailySleepDetailed:\(days)") { try await self.store.fetchDailySleepDetailed(days: days) }
        dailySleepDetailedByDays[days] = makeEntry(value)
        return value
    }

    // MARK: - VO2 Max

    func fetchLatestVO2Max() async throws -> Double? {
        if let entry = latestVO2Max, entry.isFresh { return entry.value }
        let value = try await coalesce("fetchLatestVO2Max") { try await self.store.fetchLatestVO2Max() }
        latestVO2Max = makeEntry(value)
        return value
    }

    // MARK: - External workouts

    func fetchExternalWorkouts(days: Int) async throws -> [ExternalWorkout] {
        if let entry = externalWorkoutsByDays[days], entry.isFresh { return entry.value }
        let value = try await coalesce("fetchExternalWorkouts:\(days)") { try await self.store.fetchExternalWorkouts(days: days) }
        externalWorkoutsByDays[days] = makeEntry(value)
        return value
    }

    // MARK: - Private

    /// Results are not cached at all when HealthKit is unavailable, and
    /// empty results (0 / nil / []) get a short TTL: they are often the
    /// product of denied or not-yet-granted read authorization (HealthKit
    /// hides read denial), and caching them for 5 minutes would hide data
    /// right after the user grants access.
    static let emptyTTL: TimeInterval = 20

    /// `isEmpty` overrides the reflection check for results it can't judge,
    /// such as tuples.
    private func makeEntry<T>(_ value: T, isEmpty: Bool? = nil) -> Entry<T> {
        guard store.isAvailable else { return Entry(value: value, expiresAt: .distantPast) }
        let ttl = (isEmpty ?? Self.isEmptyValue(value)) ? Self.emptyTTL : Self.ttl
        return Entry(value: value, expiresAt: .now.addingTimeInterval(ttl))
    }

    private static func isEmptyValue(_ value: Any) -> Bool {
        if let d = value as? Double { return d == 0 }
        let m = Mirror(reflecting: value)
        switch m.displayStyle {
        case .optional, .collection: return m.children.isEmpty
        default: return false
        }
    }

    // MARK: - In-flight coalescing

    private var inflight: [String: Any] = [:]

    /// Concurrent identical fetches (e.g. Home + Health cards loading at
    /// once) share a single HealthKit query.
    private func coalesce<T>(_ key: String, _ op: @escaping () async throws -> T) async throws -> T {
        if let existing = inflight[key] as? Task<T, Error> { return try await existing.value }
        let task = Task { try await op() }
        inflight[key] = task
        defer { inflight[key] = nil }
        return try await task.value
    }
}
