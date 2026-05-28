import XCTest
import SwiftData
@testable import tracker

/// Tests for `ComplianceBackfill` — the daily classifier that converts
/// observed training behaviour into `PlanComplianceEvent`s feeding the
/// trust-calibration loop. The classifier is the highest-blast-radius
/// pure function in the trust-cal pipeline: one wrong write poisons
/// the engine's confidence reading for up to a week, so we pin the
/// thresholds, idempotency, and boundary behaviour explicitly.
@MainActor
final class ComplianceBackfillTests: XCTestCase {

    /// Clear the App Group plan history before each test. Without this,
    /// the test sim's UserDefaults carries a `todayPlanHistory` blob from
    /// earlier runs (development sessions, previous test invocations)
    /// that `ComplianceBackfill.run` decodes once per day in the lookback
    /// — which made `testRunIsIdempotentAcrossInvocations` take 100 s on
    /// a polluted store. Always start from a known-empty baseline.
    override func setUp() {
        super.setUp()
        if let defaults = UserDefaults(suiteName: WidgetAppGroup.suiteName) {
            defaults.removeObject(forKey: "todayPlanHistory")
            defaults.removeObject(forKey: "currentTodayPlan")
        }
    }

    // MARK: - Helpers

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: PlanComplianceEvent.self,
            Workout.self,
            CardioSession.self,
            configurations: config
        )
    }

    private func workout(
        on day: Date,
        workingSets: Int,
        warmUpSets: Int = 0,
        weightKg: Double = 50,
        repsPerSet: Int = 10,
        finished: Bool = true
    ) -> Workout {
        let w = Workout(name: "Test", date: day)
        if finished { w.endTime = day.addingTimeInterval(45 * 60) }
        let ex = Exercise(name: "Bench", workout: w, category: .chest)
        for _ in 0..<warmUpSets {
            ex.sets.append(ExerciseSet(reps: repsPerSet, weight: weightKg, isWarmUp: true, exercise: ex))
        }
        for _ in 0..<workingSets {
            ex.sets.append(ExerciseSet(reps: repsPerSet, weight: weightKg, isWarmUp: false, exercise: ex))
        }
        w.exercises.append(ex)
        return w
    }

    private func cardio(on day: Date, minutes: Double) -> CardioSession {
        CardioSession(
            date: day,
            title: "Run",
            type: .outdoorRun,
            durationSeconds: minutes * 60,
            distanceMeters: minutes * 200   // ~10 km/h, doesn't affect classification
        )
    }

    /// Yesterday at noon — a stable past day we can attribute workouts to
    /// without colliding with the backfill loop's "today is excluded" rule.
    private func yesterday(at hour: Int = 12) -> Date {
        let cal = Calendar.current
        let start = cal.startOfDay(for: .now)
        return cal.date(byAdding: .day, value: -1, to: cal.date(byAdding: .hour, value: hour, to: start) ?? start) ?? .now
    }

    private func daysAgo(_ n: Int, hour: Int = 12) -> Date {
        let cal = Calendar.current
        let start = cal.date(byAdding: .hour, value: hour, to: cal.startOfDay(for: .now)) ?? .now
        return cal.date(byAdding: .day, value: -n, to: start) ?? .now
    }

    // MARK: - classifyActualIntensity boundary thresholds

    func testNoActivityIsRest() {
        let r = ComplianceBackfill.classifyActualIntensity(
            on: yesterday(), workouts: [], cardioSessions: []
        )
        XCTAssertEqual(r, .rest)
    }

    func testHardSetCountThresholdIsHard() {
        // Boundary: ≥ `hardSetCount` working sets is the hard threshold.
        // Pin both sides — drift here silently re-classifies real workouts.
        let day = yesterday()
        let w = workout(on: day,
                        workingSets: EngineConstants.Compliance.hardSetCount,
                        weightKg: 1, repsPerSet: 1)
        let r = ComplianceBackfill.classifyActualIntensity(
            on: day, workouts: [w], cardioSessions: []
        )
        XCTAssertEqual(r, .hard, "hardSetCount working sets should be the hard threshold")
    }

    func testOneBelowHardSetCountIsModerate() {
        // Just-below the hard threshold. Volume kept low so the volume
        // rule doesn't accidentally trip.
        let day = yesterday()
        let w = workout(on: day,
                        workingSets: EngineConstants.Compliance.hardSetCount - 1,
                        weightKg: 1, repsPerSet: 1)
        let r = ComplianceBackfill.classifyActualIntensity(
            on: day, workouts: [w], cardioSessions: []
        )
        XCTAssertEqual(r, .moderate)
    }

    func testHardVolumeThresholdIsHard() {
        // Reach exactly the volume cutoff with 10 sets × 10 reps × N kg.
        let day = yesterday()
        let weightKg = EngineConstants.Compliance.hardVolumeKg / 100   // 10 × 10 reps
        let w = workout(on: day, workingSets: 10, weightKg: weightKg, repsPerSet: 10)
        let r = ComplianceBackfill.classifyActualIntensity(
            on: day, workouts: [w], cardioSessions: []
        )
        XCTAssertEqual(r, .hard)
    }

    func testHardCardioMinutesIsHard() {
        let day = yesterday()
        let c = cardio(on: day, minutes: EngineConstants.Compliance.hardCardioMinutes)
        let r = ComplianceBackfill.classifyActualIntensity(
            on: day, workouts: [], cardioSessions: [c]
        )
        XCTAssertEqual(r, .hard)
    }

    func testLightThresholdBoundaryIsLight() {
        // Light = ≤ lightSetCount AND ≤ lightCardioMinutes. Both boundaries.
        let day = yesterday()
        let w = workout(on: day,
                        workingSets: EngineConstants.Compliance.lightSetCount,
                        weightKg: 1, repsPerSet: 1)
        let c = cardio(on: day, minutes: EngineConstants.Compliance.lightCardioMinutes)
        let r = ComplianceBackfill.classifyActualIntensity(
            on: day, workouts: [w], cardioSessions: [c]
        )
        XCTAssertEqual(r, .light)
    }

    func testOneAboveLightSetCountBumpsToModerate() {
        // Just over the light cutoff on set count → moderate.
        let day = yesterday()
        let w = workout(on: day,
                        workingSets: EngineConstants.Compliance.lightSetCount + 1,
                        weightKg: 1, repsPerSet: 1)
        let r = ComplianceBackfill.classifyActualIntensity(
            on: day, workouts: [w], cardioSessions: []
        )
        XCTAssertEqual(r, .moderate)
    }

    func testWarmupSetsAreExcludedFromCount() {
        // 25 warm-up sets + 5 working → 5 working sets → light. If warm-up
        // exclusion regresses this would classify as hard (25 ≥ 20).
        let day = yesterday()
        let w = workout(on: day, workingSets: 5, warmUpSets: 25, weightKg: 1, repsPerSet: 1)
        let r = ComplianceBackfill.classifyActualIntensity(
            on: day, workouts: [w], cardioSessions: []
        )
        XCTAssertEqual(r, .light, "Warm-up sets must not count toward intensity")
    }

    func testMultipleWorkoutsSameDayAccumulate() {
        // Two 12-set workouts → 24 working sets → hard.
        let day = yesterday()
        let w1 = workout(on: day, workingSets: 12, weightKg: 1, repsPerSet: 1)
        let w2 = workout(on: day.addingTimeInterval(3 * 3600),
                         workingSets: 12, weightKg: 1, repsPerSet: 1)
        let r = ComplianceBackfill.classifyActualIntensity(
            on: day, workouts: [w1, w2], cardioSessions: []
        )
        XCTAssertEqual(r, .hard)
    }

    func testUnfinishedWorkoutDoesntCount() {
        // A workout with endTime=nil is mid-session and shouldn't sway
        // the classifier — the user hasn't actually finished it.
        let day = yesterday()
        let w = workout(on: day, workingSets: 25, finished: false)
        let r = ComplianceBackfill.classifyActualIntensity(
            on: day, workouts: [w], cardioSessions: []
        )
        XCTAssertEqual(r, .rest, "Unfinished workout should be ignored")
    }

    func testWorkoutOnDifferentDayIsIgnored() {
        // Bug guard: classifying day N must not pick up workouts on day N-1.
        let dayUnderTest = yesterday()
        let twoDaysAgo = daysAgo(2)
        let w = workout(on: twoDaysAgo, workingSets: 30, weightKg: 1, repsPerSet: 1)
        let r = ComplianceBackfill.classifyActualIntensity(
            on: dayUnderTest, workouts: [w], cardioSessions: []
        )
        XCTAssertEqual(r, .rest)
    }

    // MARK: - run(): idempotency + skip logic

    func testRunIsIdempotentAcrossInvocations() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        // One finished workout yesterday. Note: we do NOT insert it into
        // the ModelContext — `run` reads from the passed-in array, not a
        // FetchDescriptor on the context, so the insert is pure overhead
        // and triggers an expensive Workout/Exercise/ExerciseSet
        // relationship-graph save that takes ~100 s on this simulator.
        let w = workout(on: yesterday(), workingSets: 10, weightKg: 1, repsPerSet: 1)

        // First run: writes events for the 7-day lookback.
        ComplianceBackfill.run(
            workouts: [w], cardioSessions: [], existingEvents: [], in: ctx
        )
        let firstPass = try ctx.fetch(FetchDescriptor<PlanComplianceEvent>())
        XCTAssertEqual(firstPass.count, ComplianceBackfill.lookbackDays,
                       "First run should fill the full lookback window")

        // Second run: pass back what we just wrote — must insert zero.
        ComplianceBackfill.run(
            workouts: [w], cardioSessions: [], existingEvents: firstPass, in: ctx
        )
        let secondPass = try ctx.fetch(FetchDescriptor<PlanComplianceEvent>())
        XCTAssertEqual(secondPass.count, firstPass.count,
                       "Second run with existingEvents passed must be a no-op")
    }

    func testRunSkipsToday() throws {
        // The backfill loop deliberately excludes today (`for offset in 1...`).
        // Even a finished workout dated today shouldn't appear as an event,
        // because the day isn't over yet.
        let container = try makeContainer()
        let ctx = container.mainContext

        let today = Calendar.current.startOfDay(for: .now)
            .addingTimeInterval(8 * 3600)  // 8 AM today
        let w = workout(on: today, workingSets: 25, weightKg: 1, repsPerSet: 1)
        // Same as the idempotency test: don't insert the Workout into the
        // context — the backfill consumes the array, not a fetch.
        ComplianceBackfill.run(
            workouts: [w], cardioSessions: [], existingEvents: [], in: ctx
        )
        let events = try ctx.fetch(FetchDescriptor<PlanComplianceEvent>())
        // 7 days of lookback, but none for today.
        let todayEvent = events.first { Calendar.current.isDate($0.day, inSameDayAs: today) }
        XCTAssertNil(todayEvent, "Today must be excluded from the backfill")
        XCTAssertEqual(events.count, ComplianceBackfill.lookbackDays)
    }

    func testNoCachedPlanProducesCompliedTrue() throws {
        // When the user didn't open the app on day N (no plan cached),
        // we treat compliance as true rather than flagging the user for
        // a day we don't have a reference point on. Locks in the
        // neutral-branch semantics at ComplianceBackfill.swift:46-49.
        let container = try makeContainer()
        let ctx = container.mainContext

        // App Group already cleared in setUp; TodayPlanStore.plan(on:) is nil.
        ComplianceBackfill.run(
            workouts: [], cardioSessions: [], existingEvents: [], in: ctx
        )
        let events = try ctx.fetch(FetchDescriptor<PlanComplianceEvent>())
        XCTAssertFalse(events.isEmpty)
        for e in events {
            XCTAssertTrue(e.complied,
                          "Event with no suggested plan must default to complied=true")
            XCTAssertNil(e.suggested,
                         "Suggested should be nil when no plan was cached for that day")
        }
    }

    // MARK: - Cross-component invariants

    func testLookbackFitsInsideTodayPlanStoreHistory() {
        // `ComplianceBackfill.run` calls `TodayPlanStore.plan(on:)` for every
        // day in the lookback window. If lookback exceeds the store's
        // retention, we'd ask for plans the store already pruned and
        // every event would silently get `suggested == nil` past the
        // retention edge — collapsing the trust-cal signal.
        XCTAssertLessThanOrEqual(
            ComplianceBackfill.lookbackDays,
            TodayPlanStore.historyLimit,
            "lookbackDays must fit inside the plan-history retention window"
        )
    }
}
