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

    // MARK: - Intensity nudging
    //
    // Feedback can move the recovery-derived base intensity by AT MOST
    // one bucket. Rest is sacred — the body's say-so trumps the
    // user's reported preference, so feedback never demotes rest.
    // Light is the feedback-floor (rest is reserved for recovery);
    // hard is the feedback-ceiling.

    func testFeedbackTooHardDropsHardToModerate() {
        // Recovery score in the .hard range (well-recovered) + three
        // recent "too hard" feedbacks → engine should drop intensity
        // to .moderate.
        let events = (1...3).map {
            event(daysAgo: $0, feel: .tooHard)
        }
        let plan = TodayPlanEngine.generate(
            scheduledName: nil,
            recovery: makeRecovery(score: 0.95),
            health: HealthSignals(),
            alreadyTrainedToday: false,
            feedbackEvents: events
        )
        XCTAssertEqual(plan.intensity, .moderate,
                       "Hard base + too-hard majority should drop to moderate")
        // Reason should name the OUTCOME, not just acknowledge the signal.
        XCTAssertTrue(plan.reasons.contains { $0.contains("dropping today") },
                      "Shift reason should describe the new intensity")
    }

    func testFeedbackTooEasyRaisesLightToModerate() {
        // Recovery score in the .light range + three recent
        // "too easy" feedbacks → bump intensity to .moderate.
        let events = (1...3).map {
            event(daysAgo: $0, feel: .tooEasy)
        }
        let plan = TodayPlanEngine.generate(
            scheduledName: nil,
            recovery: makeRecovery(score: 0.45),
            health: HealthSignals(),
            alreadyTrainedToday: false,
            feedbackEvents: events
        )
        XCTAssertEqual(plan.intensity, .moderate,
                       "Light base + too-easy majority should raise to moderate")
        XCTAssertTrue(plan.reasons.contains { $0.contains("bumping today") })
    }

    func testFeedbackNeverOverridesRest() {
        // Recovery score under the rest threshold + three "too easy"
        // votes → STILL rest. The body's say-so trumps user preference.
        let events = (1...3).map {
            event(daysAgo: $0, feel: .tooEasy)
        }
        let plan = TodayPlanEngine.generate(
            scheduledName: nil,
            recovery: makeRecovery(score: 0.20),
            health: HealthSignals(),
            alreadyTrainedToday: false,
            feedbackEvents: events
        )
        XCTAssertEqual(plan.intensity, .rest,
                       "Recovery's rest call must not be overridden by feedback")
        XCTAssertFalse(plan.reasons.contains { $0.contains("bumping") },
                       "No shift reason should fire when rest blocked the nudge")
    }

    func testFeedbackIsCappedAtOneBucket() {
        // Hard base + three "too hard" → drops to moderate, NOT light.
        // The contract pins a single-bucket cap.
        let events = (1...3).map {
            event(daysAgo: $0, feel: .tooHard)
        }
        let plan = TodayPlanEngine.generate(
            scheduledName: nil,
            recovery: makeRecovery(score: 0.95),
            health: HealthSignals(),
            alreadyTrainedToday: false,
            feedbackEvents: events
        )
        XCTAssertEqual(plan.intensity, .moderate,
                       "One-bucket cap: hard never drops to light from feedback alone")
    }

    func testFeedbackAtFloorFallsBackToAcknowledgment() {
        // Light base + "too hard" → can't drop further (feedback
        // floor is light; rest belongs to recovery). Should still
        // surface the gentler acknowledgment so the user knows we
        // heard them.
        let events = (1...3).map {
            event(daysAgo: $0, feel: .tooHard)
        }
        let plan = TodayPlanEngine.generate(
            scheduledName: nil,
            recovery: makeRecovery(score: 0.45),
            health: HealthSignals(),
            alreadyTrainedToday: false,
            feedbackEvents: events
        )
        XCTAssertEqual(plan.intensity, .light,
                       "Light is the feedback floor — no drop further")
        // Falls back to the acknowledgment phrasing ("taking it down")
        // rather than the concrete shift phrasing ("dropping today to").
        XCTAssertTrue(plan.reasons.contains { $0.contains("taking it down") },
                      "When feedback can't shift further, surface the acknowledgment")
        XCTAssertFalse(plan.reasons.contains { $0.contains("dropping today") },
                       "Don't claim a shift that didn't happen")
    }

    func testFeedbackAtCeilingFallsBackToAcknowledgment() {
        // Hard + "too easy" → can't raise further. Acknowledgment only.
        let events = (1...3).map {
            event(daysAgo: $0, feel: .tooEasy)
        }
        let plan = TodayPlanEngine.generate(
            scheduledName: nil,
            recovery: makeRecovery(score: 0.95),
            health: HealthSignals(),
            alreadyTrainedToday: false,
            feedbackEvents: events
        )
        XCTAssertEqual(plan.intensity, .hard,
                       "Hard is the feedback ceiling — no raise further")
        XCTAssertTrue(plan.reasons.contains { $0.contains("room to push") })
        XCTAssertFalse(plan.reasons.contains { $0.contains("bumping today") })
    }

    func testNudgeBelowSampleSizeFloorDoesNotShift() {
        // Only 2 events, floor is 3 → no nudge, no shift, no reason.
        let events = [
            event(daysAgo: 1, feel: .tooHard),
            event(daysAgo: 2, feel: .tooHard),
        ]
        let plan = TodayPlanEngine.generate(
            scheduledName: nil,
            recovery: makeRecovery(score: 0.95),
            health: HealthSignals(),
            alreadyTrainedToday: false,
            feedbackEvents: events
        )
        XCTAssertEqual(plan.intensity, .hard,
                       "Below sample-size floor, intensity should stay at base")
    }

    // MARK: - nudgeIntensity pure helper

    func testNudgeIntensityNoFeedbackReturnsBase() {
        for base in [TodayPlan.Intensity.rest, .light, .moderate, .hard] {
            XCTAssertEqual(
                TodayPlanEngine.nudgeIntensity(base: base, byFeedback: nil),
                base
            )
        }
    }

    func testNudgeIntensityCoverageMatrix() {
        // Pin every cell of the nudge matrix so a future tweak that
        // accidentally changes one row gets caught.
        let cases: [(TodayPlan.Intensity, WorkoutFeedbackEvent.Feel, TodayPlan.Intensity)] = [
            (.rest,     .tooHard,     .rest),
            (.rest,     .tooEasy,     .rest),
            (.rest,     .aboutRight,  .rest),
            (.light,    .tooHard,     .light),
            (.light,    .tooEasy,     .moderate),
            (.light,    .aboutRight,  .light),
            (.moderate, .tooHard,     .light),
            (.moderate, .tooEasy,     .hard),
            (.moderate, .aboutRight,  .moderate),
            (.hard,     .tooHard,     .moderate),
            (.hard,     .tooEasy,     .hard),
            (.hard,     .aboutRight,  .hard),
        ]
        for (base, feel, expected) in cases {
            XCTAssertEqual(
                TodayPlanEngine.nudgeIntensity(base: base, byFeedback: feel),
                expected,
                "\(base) + \(feel) should produce \(expected)"
            )
        }
    }
}
