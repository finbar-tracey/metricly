import XCTest
@testable import tracker

/// Tests for `WorkoutFeedbackEvent` + the engine integration.
///
/// Two layers:
///   1. **Model + summary** — Feel rawValues are stable; init clamps
///      to startOfDay; `recentFeedback` honours the lookback window
///      and computes the majority correctly.
///   2. **Engine integration** — `TodayPlanEngine.generate` adds the
///      right reason line per majority bucket, and stays silent when
///      the sample size is below the floor or no bucket dominates.
final class WorkoutFeedbackTests: XCTestCase {

    // MARK: - Helpers

    private func event(
        daysAgo: Int,
        feel: WorkoutFeedbackEvent.Feel,
        suggested: TodayPlan.Intensity? = .moderate
    ) -> WorkoutFeedbackEvent {
        let day = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
        return WorkoutFeedbackEvent(day: day, feel: feel, suggested: suggested)
    }

    private func makeRecovery(score: Double) -> RecoveryResult {
        RecoveryResult(
            readinessScore: score,
            muscleResults: [],
            suggestedWorkoutType: "Push"
        )
    }

    // MARK: - Feel enum + init

    func testFeelRawValuesAreStable() {
        // Pin both directions — these strings live on persisted
        // CloudKit rows; renames are a migration, not a rename.
        XCTAssertEqual(WorkoutFeedbackEvent.Feel.tooEasy.rawValue,    "too_easy")
        XCTAssertEqual(WorkoutFeedbackEvent.Feel.aboutRight.rawValue, "about_right")
        XCTAssertEqual(WorkoutFeedbackEvent.Feel.tooHard.rawValue,    "too_hard")
        XCTAssertEqual(WorkoutFeedbackEvent.Feel(rawValue: "too_easy"),    .tooEasy)
        XCTAssertEqual(WorkoutFeedbackEvent.Feel(rawValue: "about_right"), .aboutRight)
        XCTAssertEqual(WorkoutFeedbackEvent.Feel(rawValue: "too_hard"),    .tooHard)
    }

    func testInitNormalisesDayToStartOfDay() {
        let noonToday = Calendar.current.date(
            bySettingHour: 12, minute: 30, second: 0, of: .now
        ) ?? .now
        let event = WorkoutFeedbackEvent(day: noonToday, feel: .aboutRight, suggested: .moderate)
        XCTAssertEqual(event.day, Calendar.current.startOfDay(for: noonToday),
                       "Init must clamp the timestamp to startOfDay for stable day-keyed lookups")
    }

    func testInitWithNilSuggestedStoresEmptyString() {
        let event = WorkoutFeedbackEvent(day: .now, feel: .tooHard, suggested: nil)
        XCTAssertEqual(event.suggestedIntensityRaw, "")
        XCTAssertNil(event.suggested)
    }

    // MARK: - FeedbackSummary

    func testRecentFeedbackReturnsNilForEmptyInput() {
        XCTAssertNil(TodayPlanEngine.recentFeedback(events: []))
    }

    func testRecentFeedbackDropsEventsOutsideLookback() {
        let stale = event(daysAgo: 30, feel: .tooHard)
        XCTAssertNil(TodayPlanEngine.recentFeedback(events: [stale]),
                     "Events older than the lookback window shouldn't be counted")
    }

    func testRecentFeedbackCountsAllInWindow() {
        let events = [
            event(daysAgo: 1, feel: .tooHard),
            event(daysAgo: 2, feel: .tooHard),
            event(daysAgo: 3, feel: .aboutRight),
        ]
        let summary = TodayPlanEngine.recentFeedback(events: events)
        XCTAssertEqual(summary?.sampleSize, 3)
        XCTAssertEqual(summary?.countByFeel[.tooHard], 2)
        XCTAssertEqual(summary?.countByFeel[.aboutRight], 1)
    }

    func testRecentFeedbackMajorityNeeds60Percent() {
        // 3 out of 4 = 75% = passes the 60% threshold.
        let dominant = [
            event(daysAgo: 1, feel: .tooHard),
            event(daysAgo: 2, feel: .tooHard),
            event(daysAgo: 3, feel: .tooHard),
            event(daysAgo: 4, feel: .aboutRight),
        ]
        XCTAssertEqual(
            TodayPlanEngine.recentFeedback(events: dominant)?.majority,
            .tooHard
        )

        // 2 out of 4 = 50% — below the 60% threshold; no majority.
        let split = [
            event(daysAgo: 1, feel: .tooHard),
            event(daysAgo: 2, feel: .tooHard),
            event(daysAgo: 3, feel: .aboutRight),
            event(daysAgo: 4, feel: .aboutRight),
        ]
        XCTAssertNil(TodayPlanEngine.recentFeedback(events: split)?.majority,
                     "50/50 split must not produce a majority — 60% threshold")
    }

    // MARK: - Engine integration

    func testEngineAddsReasonForTooHardMajority() {
        let events = [
            event(daysAgo: 1, feel: .tooHard),
            event(daysAgo: 2, feel: .tooHard),
            event(daysAgo: 3, feel: .tooHard),
        ]
        let plan = TodayPlanEngine.generate(
            scheduledName: nil,
            recovery: makeRecovery(score: 0.75),
            health: HealthSignals(),
            alreadyTrainedToday: false,
            feedbackEvents: events
        )
        XCTAssertTrue(plan.reasons.contains { $0.contains("tough") },
                      "A clear too-hard majority should surface a reason line")
    }

    func testEngineAddsReasonForTooEasyMajority() {
        let events = [
            event(daysAgo: 1, feel: .tooEasy),
            event(daysAgo: 2, feel: .tooEasy),
            event(daysAgo: 3, feel: .tooEasy),
        ]
        let plan = TodayPlanEngine.generate(
            scheduledName: nil,
            recovery: makeRecovery(score: 0.75),
            health: HealthSignals(),
            alreadyTrainedToday: false,
            feedbackEvents: events
        )
        XCTAssertTrue(plan.reasons.contains { $0.contains("easy") },
                      "A clear too-easy majority should surface a reason line")
    }

    func testEngineStaysSilentOnAboutRightMajority() {
        // Plan agreeing with the user is the default state — should
        // not produce a reason line ("staying the course" feels like
        // padding when nothing's wrong).
        let events = [
            event(daysAgo: 1, feel: .aboutRight),
            event(daysAgo: 2, feel: .aboutRight),
            event(daysAgo: 3, feel: .aboutRight),
        ]
        let plan = TodayPlanEngine.generate(
            scheduledName: nil,
            recovery: makeRecovery(score: 0.75),
            health: HealthSignals(),
            alreadyTrainedToday: false,
            feedbackEvents: events
        )
        XCTAssertFalse(plan.reasons.contains { $0.contains("hit the mark") },
                       "About-right majority should NOT add a reason — it's the default state")
        XCTAssertFalse(plan.reasons.contains { $0.contains("course") })
    }

    func testEngineStaysSilentBelowSampleSizeFloor() {
        // Only 2 events; floor is 3.
        let events = [
            event(daysAgo: 1, feel: .tooHard),
            event(daysAgo: 2, feel: .tooHard),
        ]
        let plan = TodayPlanEngine.generate(
            scheduledName: nil,
            recovery: makeRecovery(score: 0.75),
            health: HealthSignals(),
            alreadyTrainedToday: false,
            feedbackEvents: events
        )
        XCTAssertFalse(plan.reasons.contains { $0.contains("tough") },
                       "Below sample-size floor, no feedback reason should fire")
    }

    func testEngineStaysSilentOnMixedFeedback() {
        // No clear majority — should not produce a reason line.
        let events = [
            event(daysAgo: 1, feel: .tooHard),
            event(daysAgo: 2, feel: .tooEasy),
            event(daysAgo: 3, feel: .aboutRight),
            event(daysAgo: 4, feel: .tooHard),
        ]
        let plan = TodayPlanEngine.generate(
            scheduledName: nil,
            recovery: makeRecovery(score: 0.75),
            health: HealthSignals(),
            alreadyTrainedToday: false,
            feedbackEvents: events
        )
        XCTAssertFalse(plan.reasons.contains { $0.contains("tough") })
        XCTAssertFalse(plan.reasons.contains { $0.contains("easy") })
    }
}
