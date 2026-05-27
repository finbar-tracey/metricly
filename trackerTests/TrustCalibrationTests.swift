import XCTest
@testable import tracker

/// Tests for the trust-calibration loop — turning "engine suggests X,
/// user does Y" history into a confidence + reason adjustment on the
/// next plan.
final class TrustCalibrationTests: XCTestCase {

    private func event(daysAgo: Int, suggested: TodayPlan.Intensity?, actual: TodayPlan.Intensity, complied: Bool? = nil) -> PlanComplianceEvent {
        let day = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
        let auto = complied ?? (suggested?.matches(actual) ?? true)
        return PlanComplianceEvent(day: day, suggested: suggested, actual: actual, complied: auto)
    }

    // MARK: - matches() classifier

    func testMatchesIdentityIsTrue() {
        for k in [TodayPlan.Intensity.rest, .light, .moderate, .hard] {
            XCTAssertTrue(k.matches(k), "\(k) should match itself")
        }
    }

    func testMatchesNeighboursAreTrue() {
        // Soft matches around the bucket boundaries.
        XCTAssertTrue(TodayPlan.Intensity.light.matches(.moderate))
        XCTAssertTrue(TodayPlan.Intensity.moderate.matches(.light))
        XCTAssertTrue(TodayPlan.Intensity.moderate.matches(.hard))
        XCTAssertTrue(TodayPlan.Intensity.hard.matches(.moderate))
    }

    func testMatchesAcrossRestAndTrainingIsFalse() {
        // Rest vs anything else is always a hard mismatch — this is
        // the case that matters most for the trust-cal trigger.
        XCTAssertFalse(TodayPlan.Intensity.rest.matches(.light))
        XCTAssertFalse(TodayPlan.Intensity.rest.matches(.moderate))
        XCTAssertFalse(TodayPlan.Intensity.rest.matches(.hard))
        XCTAssertFalse(TodayPlan.Intensity.hard.matches(.rest))
        // Light vs hard is also a non-trivial gap.
        XCTAssertFalse(TodayPlan.Intensity.light.matches(.hard))
        XCTAssertFalse(TodayPlan.Intensity.hard.matches(.light))
    }

    // MARK: - recentCompliance summary

    func testEmptyEventsProduceNilSummary() {
        XCTAssertNil(TodayPlanEngine.recentCompliance(events: []))
    }

    func testEventsOutsideLookbackAreIgnored() {
        // Lookback is 7 days; this event is 30 days ago.
        let old = event(daysAgo: 30, suggested: .rest, actual: .hard)
        XCTAssertNil(TodayPlanEngine.recentCompliance(events: [old]))
    }

    func testEventsWithoutSuggestionAreIgnored() {
        // Cached plan was missing for that day — neutral, doesn't count
        // against the user.
        let none = event(daysAgo: 1, suggested: nil, actual: .hard)
        XCTAssertNil(TodayPlanEngine.recentCompliance(events: [none]))
    }

    func testRateAndSampleSize() {
        let events = [
            event(daysAgo: 1, suggested: .rest, actual: .hard),           // ignored
            event(daysAgo: 2, suggested: .light, actual: .moderate),      // matches (soft)
            event(daysAgo: 3, suggested: .moderate, actual: .moderate),   // matches
            event(daysAgo: 4, suggested: .hard, actual: .rest),           // ignored
        ]
        let summary = TodayPlanEngine.recentCompliance(events: events)
        XCTAssertEqual(summary?.sampleSize, 4)
        XCTAssertEqual(summary?.rate ?? 0, 0.5, accuracy: 0.001)
    }

    func testMostIgnoredKindReturnsTopBucket() {
        let events = [
            event(daysAgo: 1, suggested: .rest, actual: .hard),
            event(daysAgo: 2, suggested: .rest, actual: .moderate),
            event(daysAgo: 3, suggested: .light, actual: .hard),
        ]
        let summary = TodayPlanEngine.recentCompliance(events: events)
        XCTAssertEqual(summary?.mostIgnoredKind, .rest)
        XCTAssertEqual(summary?.ignoredCount(for: .rest), 2)
        XCTAssertEqual(summary?.ignoredCount(for: .light), 1)
    }

    // MARK: - Copy

    func testComplianceReasonCopyIsNonEmpty() {
        // Defensive: each bucket should produce a non-empty, human-
        // readable string. Avoids regressions where a new Intensity
        // case is added but copy isn't wired.
        for kind in [TodayPlan.Intensity.rest, .light, .moderate, .hard] {
            let copy = TodayPlanEngine.complianceReasonCopy(for: kind, ignored: 3)
            XCTAssertFalse(copy.isEmpty, "Copy for \(kind) shouldn't be empty")
        }
    }

    // MARK: - Backfill classifier

    func testClassifyActualIntensityNoActivityIsRest() {
        let day = Date()
        let result = ComplianceBackfill.classifyActualIntensity(
            on: day, workouts: [], cardioSessions: []
        )
        XCTAssertEqual(result, .rest)
    }
}
