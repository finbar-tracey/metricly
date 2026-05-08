import XCTest
@testable import tracker

final class ProgressionAdvisorTests: XCTestCase {

    // MARK: - Increment by muscle group

    func testLegsUseLargerIncrement() {
        XCTAssertEqual(ProgressionAdvisor.increment(for: .legs), 5.0)
    }

    func testNonLegMusclesUseSmallerIncrement() {
        XCTAssertEqual(ProgressionAdvisor.increment(for: .chest), 2.5)
        XCTAssertEqual(ProgressionAdvisor.increment(for: .back), 2.5)
        XCTAssertEqual(ProgressionAdvisor.increment(for: .biceps), 2.5)
        XCTAssertEqual(ProgressionAdvisor.increment(for: nil), 2.5)
    }

    // MARK: - Insufficient data

    func testEmptySessionsReturnsInsufficient() {
        let result = ProgressionAdvisor.recommend(sessions: [], muscleGroup: .chest)
        if case .insufficient = result.action {} else {
            XCTFail("Expected .insufficient for empty sessions")
        }
    }

    func testSingleSessionReturnsInsufficient() {
        let one = makeSession(daysAgo: 0, weight: 80, reps: 8)
        let result = ProgressionAdvisor.recommend(sessions: [one], muscleGroup: .chest)
        if case .insufficient = result.action {} else {
            XCTFail("Expected .insufficient with only one session")
        }
    }

    // MARK: - RPE-based path

    func testLowRPESuggestsIncrease() {
        // Both sessions averaged RPE 7 — low effort, time to add weight
        let latest = makeSession(daysAgo: 0, weight: 80, reps: 8, rpe: 7)
        let prev   = makeSession(daysAgo: -7, weight: 80, reps: 8, rpe: 7)
        let result = ProgressionAdvisor.recommend(sessions: [latest, prev], muscleGroup: .chest)
        guard case let .increase(suggested) = result.action else {
            return XCTFail("Expected .increase, got \(result.action)")
        }
        // Chest increment is 2.5 kg
        XCTAssertEqual(suggested, 82.5, accuracy: 0.01)
    }

    func testMediumRPESuggestsHold() {
        // RPE 8.5 — challenging but productive
        let latest = makeSession(daysAgo: 0, weight: 100, reps: 5, rpe: 9)
        let prev   = makeSession(daysAgo: -7, weight: 100, reps: 5, rpe: 8)
        let result = ProgressionAdvisor.recommend(sessions: [latest, prev], muscleGroup: .chest)
        if case .hold = result.action {} else {
            XCTFail("Expected .hold for medium RPE, got \(result.action)")
        }
    }

    func testHighRPESuggestsDeload() {
        // RPE 9.5+ — bordering on grinding, should deload
        let latest = makeSession(daysAgo: 0, weight: 110, reps: 5, rpe: 10)
        let prev   = makeSession(daysAgo: -7, weight: 110, reps: 5, rpe: 9)
        let result = ProgressionAdvisor.recommend(sessions: [latest, prev], muscleGroup: .chest)
        if case .deload = result.action {} else {
            XCTFail("Expected .deload for very high RPE, got \(result.action)")
        }
    }

    // MARK: - No-RPE fallback

    func testWeightIncreaseWithoutRPESuggestsContinue() {
        let latest = makeSession(daysAgo: 0, weight: 85, reps: 8)
        let prev   = makeSession(daysAgo: -7, weight: 80, reps: 8)
        let result = ProgressionAdvisor.recommend(sessions: [latest, prev], muscleGroup: .chest)
        if case .increase = result.action {} else {
            XCTFail("Expected .increase when weight went up")
        }
    }

    func testRepIncreaseAtSameWeightSuggestsIncrease() {
        let latest = makeSession(daysAgo: 0, weight: 80, reps: 10)
        let prev   = makeSession(daysAgo: -7, weight: 80, reps: 8)
        let result = ProgressionAdvisor.recommend(sessions: [latest, prev], muscleGroup: .back)
        if case .increase = result.action {} else {
            XCTFail("Expected .increase when reps went up at same weight")
        }
    }

    func testIdenticalSessionsSuggestHold() {
        let latest = makeSession(daysAgo: 0, weight: 80, reps: 8)
        let prev   = makeSession(daysAgo: -7, weight: 80, reps: 8)
        let result = ProgressionAdvisor.recommend(sessions: [latest, prev], muscleGroup: .chest)
        if case .hold = result.action {} else {
            XCTFail("Expected .hold for identical sessions")
        }
    }

    func testMinorDipSuggestsHold() {
        // One bad session shouldn't trigger a deload
        let latest = makeSession(daysAgo: 0, weight: 78, reps: 8)
        let prev   = makeSession(daysAgo: -7, weight: 80, reps: 8)
        let result = ProgressionAdvisor.recommend(sessions: [latest, prev], muscleGroup: .chest)
        if case .hold = result.action {} else {
            XCTFail("Expected .hold for a minor dip, got \(result.action)")
        }
    }

    func testSustainedDeclineSuggestsDeload() {
        // Three-session declining trend
        let latest  = makeSession(daysAgo: 0,   weight: 78, reps: 8)
        let middle  = makeSession(daysAgo: -7,  weight: 80, reps: 8)
        let oldest  = makeSession(daysAgo: -14, weight: 82, reps: 8)
        let result = ProgressionAdvisor.recommend(sessions: [latest, middle, oldest], muscleGroup: .chest)
        if case .deload = result.action {} else {
            XCTFail("Expected .deload for sustained decline, got \(result.action)")
        }
    }

    // MARK: - Increment respects muscle group on increase recommendations

    func testLegsUseFiveKgIncrementInRecommendation() {
        let latest = makeSession(daysAgo: 0, weight: 140, reps: 5, rpe: 7)
        let prev   = makeSession(daysAgo: -7, weight: 140, reps: 5, rpe: 7)
        let result = ProgressionAdvisor.recommend(sessions: [latest, prev], muscleGroup: .legs)
        guard case let .increase(suggested) = result.action else {
            return XCTFail("Expected .increase")
        }
        XCTAssertEqual(suggested, 145.0, accuracy: 0.01, "Legs should add 5 kg, not 2.5")
    }

    // MARK: - Helpers

    private func makeSession(daysAgo: Int, weight: Double, reps: Int, rpe: Int? = nil) -> SessionSummary {
        let date = Calendar.current.date(byAdding: .day, value: daysAgo, to: .now)!
        let avgRPE = rpe.map(Double.init)
        let est1RM = reps == 1 ? weight : weight * (1.0 + Double(reps) / 30.0)
        return SessionSummary(date: date, topWeight: weight, topReps: reps,
                               avgRPE: avgRPE, estimated1RM: est1RM)
    }
}
