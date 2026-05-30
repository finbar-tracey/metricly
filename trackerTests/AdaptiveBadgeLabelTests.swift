import XCTest
@testable import tracker

/// **Spec mirror** for the deload-aware adaptive badge rule that lives
/// in two places:
///
///   - `MetriclyWatchComplications.adaptiveBadgeLabel(intensity:blockPhase:)`
///   - `WatchGymView.adaptiveBadgeText`
///
/// Both are short pure functions duplicated across the watch + the
/// complications target (each target only sees its own symbols, so a
/// shared module would mean a new project-file entry for one tiny
/// function). The duplication is acceptable as long as **both copies
/// match this spec** — if you change one, change the other, and
/// update the table below.
///
/// The spec captures the rule the watch user experiences:
///   - `.rest` always wins (recovery-engine rest overrides
///     periodisation override; we never tell the user to lift
///     during a doctor-ordered rest day).
///   - Otherwise, during a `.deload` block, every non-rest intensity
///     reads as "Deload" — the periodisation context replaces the
///     intensity label on the watch glance.
///   - Outside a deload, `.light`/`.hard` surface by name;
///     `.moderate` returns nil (no badge worth showing).
final class AdaptiveBadgeLabelTests: XCTestCase {

    /// Local spec implementation — mirrors both production copies
    /// exactly. Tests run against this to verify the matrix, and
    /// reviewers diff against the prod functions to confirm parity.
    private func spec(intensity: String, blockPhase: String) -> String? {
        if intensity == "rest" { return "Rest" }
        if blockPhase == "deload" { return "Deload" }
        switch intensity {
        case "light": return "Light"
        case "hard":  return "Hard"
        default:      return nil
        }
    }

    // MARK: - Rest precedence

    func testRestBeatsDeloadBlock() {
        XCTAssertEqual(spec(intensity: "rest", blockPhase: "deload"), "Rest",
                       "Recovery rest day overrides periodisation override")
    }

    func testRestBeatsAccumulateBlock() {
        XCTAssertEqual(spec(intensity: "rest", blockPhase: "accumulate"), "Rest")
    }

    func testRestWithNoBlock() {
        XCTAssertEqual(spec(intensity: "rest", blockPhase: ""), "Rest")
    }

    // MARK: - Deload overrides non-rest intensity

    func testDeloadOverridesLight() {
        XCTAssertEqual(spec(intensity: "light", blockPhase: "deload"), "Deload",
                       "During deload, even a light day reads as Deload — the user sees the block context")
    }

    func testDeloadOverridesModerate() {
        // Engine caps to .light during deload so this is a defensive
        // pin — if the cap ever regresses, the badge should still
        // signal deload rather than disappearing entirely.
        XCTAssertEqual(spec(intensity: "moderate", blockPhase: "deload"), "Deload")
    }

    func testDeloadOverridesHard() {
        // Same defence — if a future writer skips the deload cap and
        // emits .hard, the badge still reads Deload.
        XCTAssertEqual(spec(intensity: "hard", blockPhase: "deload"), "Deload")
    }

    // MARK: - Outside a deload — intensity wins

    func testAccumulateLightShowsLight() {
        XCTAssertEqual(spec(intensity: "light", blockPhase: "accumulate"), "Light",
                       "Accumulate light day reads as Light — periodisation context only applies during deload")
    }

    func testAccumulateModerateReturnsNil() {
        XCTAssertNil(spec(intensity: "moderate", blockPhase: "accumulate"),
                     "Moderate is the neutral default — no badge")
    }

    func testAccumulateHardShowsHard() {
        XCTAssertEqual(spec(intensity: "hard", blockPhase: "accumulate"), "Hard")
    }

    // MARK: - No block context

    func testNoBlockLight() {
        XCTAssertEqual(spec(intensity: "light", blockPhase: ""), "Light")
    }

    func testNoBlockModerate() {
        XCTAssertNil(spec(intensity: "moderate", blockPhase: ""))
    }

    func testNoBlockHard() {
        XCTAssertEqual(spec(intensity: "hard", blockPhase: ""), "Hard")
    }

    // MARK: - Defensive edges

    func testUnknownIntensityWithDeloadStillProducesDeload() {
        // Future intensity case (e.g. ".maintenance") not yet handled
        // — during deload it should still signal Deload rather than
        // disappearing.
        XCTAssertEqual(spec(intensity: "maintenance", blockPhase: "deload"), "Deload")
    }

    func testUnknownIntensityWithoutDeloadReturnsNil() {
        XCTAssertNil(spec(intensity: "maintenance", blockPhase: ""))
    }
}
