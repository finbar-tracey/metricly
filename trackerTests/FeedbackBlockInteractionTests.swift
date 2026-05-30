import XCTest
@testable import tracker

/// Cross-feature tests for the interaction between user feedback
/// (`WorkoutFeedbackEvent.Feel`) and the periodisation block
/// (`TrainingBlock.Phase`). Two systems that both influence today's
/// intensity, each correct in isolation; this file covers the
/// combinations.
///
/// **Sprint 38 motivation.** The v1.8 review pass caught that the
/// reason copy compared the FINAL intensity against `baseIntensity`
/// to decide between "feedback shifted things" (concrete copy) and
/// "feedback was heard" (acknowledgment copy). When a deload cap
/// forced the final intensity down past where feedback wanted to
/// land, the concrete copy fired and misattributed the drop to
/// feedback. The fix compares `postFeedbackIntensity` against
/// `baseIntensity` so the concrete copy only fires when feedback
/// itself was the cause.
///
/// These tests pin the corrected behaviour so a future regression
/// surfaces immediately.
final class FeedbackBlockInteractionTests: XCTestCase {

    // MARK: - Helpers

    private func event(
        daysAgo: Int,
        feel: WorkoutFeedbackEvent.Feel
    ) -> WorkoutFeedbackEvent {
        let day = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
        return WorkoutFeedbackEvent(day: day, feel: feel, suggested: .moderate)
    }

    private func makeRecovery(score: Double) -> RecoveryResult {
        RecoveryResult(
            readinessScore: score,
            muscleResults: [],
            suggestedWorkoutType: "Push"
        )
    }

    private func deloadBlock() -> TrainingBlock {
        TrainingBlock(
            startDate: Calendar.current.date(byAdding: .day, value: -3, to: .now) ?? .now,
            weekCount: 1,
            phase: .deload
        )
    }

    private func accumulateBlock() -> TrainingBlock {
        TrainingBlock(
            startDate: Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now,
            weekCount: 4,
            phase: .accumulate
        )
    }

    // MARK: - Deload cap + feedback interaction

    func testDeloadCapBeatsTooEasyNudge() {
        // High recovery + tooEasy majority would normally bump base
        // .hard → .hard (ceiling) or .moderate → .hard. With a deload
        // block active, the cap forces .light regardless.
        let events: [WorkoutFeedbackEvent] = (1...3).map {
            event(daysAgo: $0, feel: .tooEasy)
        }
        let plan = TodayPlanEngine.generate(
            scheduledName: nil,
            recovery: makeRecovery(score: 0.85),
            health: HealthSignals(),
            alreadyTrainedToday: false,
            feedbackEvents: events,
            currentBlock: deloadBlock()
        )
        XCTAssertEqual(plan.intensity, .light,
                       "Deload cap must beat a tooEasy nudge — the periodisation override sits above feedback")
    }

    func testDeloadCapAlreadyLightStillProducesLight() {
        // Moderate recovery + no feedback → .moderate base.
        // Deload cap → .light final.
        let plan = TodayPlanEngine.generate(
            scheduledName: nil,
            recovery: makeRecovery(score: 0.65),
            health: HealthSignals(),
            alreadyTrainedToday: false,
            currentBlock: deloadBlock()
        )
        XCTAssertEqual(plan.intensity, .light)
    }

    func testDeloadCapWithTooHardKeepsLight() {
        // Base .hard + tooHard nudge → would land .moderate.
        // Deload cap → .light final.
        let events: [WorkoutFeedbackEvent] = (1...3).map {
            event(daysAgo: $0, feel: .tooHard)
        }
        let plan = TodayPlanEngine.generate(
            scheduledName: nil,
            recovery: makeRecovery(score: 0.85),
            health: HealthSignals(),
            alreadyTrainedToday: false,
            feedbackEvents: events,
            currentBlock: deloadBlock()
        )
        XCTAssertEqual(plan.intensity, .light,
                       "Both feedback nudge and deload cap push down — final is still light")
    }

    // MARK: - Reason copy attribution (Sprint 38-A regression guard)

    func testDeloadDrivenDropUsesAcknowledgmentCopy() {
        // The bug this test guards against: base .hard + tooHard
        // nudge wants → .moderate. Deload cap forces → .light. The
        // OLD code would say "Heard you — dropping today to LIGHT"
        // (intensity .light != baseIntensity .hard) which falsely
        // credits feedback for landing at .light. The fix uses the
        // acknowledgment copy because the FEEDBACK NUDGE itself only
        // moved .hard → .moderate.
        let events: [WorkoutFeedbackEvent] = (1...3).map {
            event(daysAgo: $0, feel: .tooHard)
        }
        let plan = TodayPlanEngine.generate(
            scheduledName: nil,
            recovery: makeRecovery(score: 0.85),
            health: HealthSignals(),
            alreadyTrainedToday: false,
            feedbackEvents: events,
            currentBlock: deloadBlock()
        )
        // The acknowledgment copy mentions "Heard" or "tough" but
        // doesn't say "dropping to light" — because the feedback
        // nudge wanted .moderate, not .light. The deload-week reason
        // line (separate) names the actual cause of landing at light.
        let lightShiftReason = plan.reasons.first {
            $0.lowercased().contains("dropping") && $0.lowercased().contains("light")
        }
        XCTAssertNil(lightShiftReason,
                     "Feedback reason must NOT claim 'dropping to light' when the deload cap caused the drop. Got reasons: \(plan.reasons)")
        XCTAssertTrue(plan.reasons.contains { $0.lowercased().contains("deload") },
                      "Deload reason line should still surface as the explanation for the drop")
    }

    func testAccumulateTooHardUsesConcreteShiftCopy() {
        // Sanity check the corrected branch: outside a deload, base
        // .hard + tooHard nudge → .moderate is a real feedback-driven
        // shift, and the concrete copy SHOULD fire.
        let events: [WorkoutFeedbackEvent] = (1...3).map {
            event(daysAgo: $0, feel: .tooHard)
        }
        let plan = TodayPlanEngine.generate(
            scheduledName: nil,
            recovery: makeRecovery(score: 0.85),
            health: HealthSignals(),
            alreadyTrainedToday: false,
            feedbackEvents: events,
            currentBlock: accumulateBlock()
        )
        XCTAssertEqual(plan.intensity, .moderate,
                       "Accumulate week + tooHard nudge: base hard → moderate stands")
        let concreteShift = plan.reasons.first {
            $0.lowercased().contains("dropping") || $0.lowercased().contains("moderate")
        }
        XCTAssertNotNil(concreteShift,
                        "When feedback itself shifted intensity, the concrete shift reason should fire. Reasons: \(plan.reasons)")
    }

    // MARK: - Accumulate doesn't tamper with feedback bumps

    func testAccumulateTooEasyBumpsAsNormal() {
        // Outside a deload, the engine's normal too-easy nudge
        // applies. Base .moderate (score 0.65) + tooEasy → .hard.
        let events: [WorkoutFeedbackEvent] = (1...3).map {
            event(daysAgo: $0, feel: .tooEasy)
        }
        let plan = TodayPlanEngine.generate(
            scheduledName: nil,
            recovery: makeRecovery(score: 0.65),
            health: HealthSignals(),
            alreadyTrainedToday: false,
            feedbackEvents: events,
            currentBlock: accumulateBlock()
        )
        XCTAssertEqual(plan.intensity, .hard,
                       "Accumulate + tooEasy nudge: bump moderate → hard with no block override")
    }

    // MARK: - Rest sacred under both signals

    func testDeloadDoesNotPromoteRestEvenWithTooEasy() {
        // Low recovery → base .rest. tooEasy nudge wouldn't change
        // rest (engine treats rest as sacred). Deload also can't
        // promote rest. Belt-and-braces.
        let events: [WorkoutFeedbackEvent] = (1...3).map {
            event(daysAgo: $0, feel: .tooEasy)
        }
        let plan = TodayPlanEngine.generate(
            scheduledName: nil,
            recovery: makeRecovery(score: 0.20),
            health: HealthSignals(),
            alreadyTrainedToday: false,
            feedbackEvents: events,
            currentBlock: deloadBlock()
        )
        XCTAssertEqual(plan.intensity, .rest)
    }
}
