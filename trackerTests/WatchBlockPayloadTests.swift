import XCTest
import SwiftData
@testable import tracker

/// Tests for the iPhone → Watch training-block payload added in
/// Sprint 32. Two layers:
///
///   1. **Key contract.** `WatchMessageKey.blockPhase` and
///      `.blockWeekLabel` must exist as exact, stable strings —
///      both sides hardcode them (the watch target literally
///      duplicates the strings in `WatchSharedKeys` since it can't
///      import the iPhone-side enum), so a silent rename would
///      manifest as the watch never seeing block context without
///      any compile error.
///
///   2. **Transform contract.** The phone side resolves the active
///      block via `TrainingBlockEngine.currentBlock` and
///      pre-formats the "Week N of M" label via
///      `progressLabel(for:)`. Those two transforms are the only
///      block-related logic on the wire — verify they produce the
///      strings the watch expects in the standard cases.
///
/// The full `PhoneConnectivityManager.collectWatchContext` dict
/// assembly isn't tested here because it requires a fully-wired
/// `ModelContext` + `WCSession` setup; covering the inputs the
/// dict reads from is the higher-leverage check.
final class WatchBlockPayloadTests: XCTestCase {

    // MARK: - Key contract

    func testBlockPhaseKeyMatchesContractedString() {
        XCTAssertEqual(WatchMessageKey.blockPhase, "blockPhase",
                       "Watch + phone hardcode this string on both sides — never rename without bumping both")
    }

    func testBlockWeekLabelKeyMatchesContractedString() {
        XCTAssertEqual(WatchMessageKey.blockWeekLabel, "blockWeekLabel",
                       "Watch + phone hardcode this string on both sides — never rename without bumping both")
    }

    // MARK: - Transform contract

    private let cal = Calendar.current
    private static let anchor: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 3; c.day = 15
        c.hour = 9; c.minute = 0
        return Calendar.current.date(from: c) ?? .distantPast
    }()

    private func day(_ offset: Int) -> Date {
        cal.date(byAdding: .day, value: offset, to: WatchBlockPayloadTests.anchor)
            ?? WatchBlockPayloadTests.anchor
    }

    func testActiveBlockProducesPhaseAndWeekLabel() {
        // The two values the phone puts in the dict are exactly
        // `phase.rawValue` and `progressLabel(for:)`. Pin both for a
        // concrete mid-block date.
        let block = TrainingBlock(startDate: day(0), weekCount: 4, phase: .accumulate)
        let blocks = [block]

        let active = TrainingBlockEngine.currentBlock(in: blocks, at: day(8))
        XCTAssertNotNil(active)
        XCTAssertEqual(active?.phase.rawValue, "accumulate",
                       "Phase rawValue is what lands in the wire payload — must stay 'accumulate'")
        XCTAssertEqual(TrainingBlockEngine.progressLabel(for: block, at: day(8)),
                       "Week 2 of 4",
                       "Watch parses 'Week N of M' to a compact 'Wk N/M'; the prefix/separator literals are part of the contract")
    }

    func testDeloadBlockSerializesCorrectly() {
        let block = TrainingBlock(startDate: day(0), weekCount: 1, phase: .deload)
        let active = TrainingBlockEngine.currentBlock(in: [block], at: day(3))
        XCTAssertEqual(active?.phase.rawValue, "deload")
        XCTAssertEqual(TrainingBlockEngine.progressLabel(for: block, at: day(3)), "Week 1 of 1")
    }

    func testNoActiveBlockReturnsNil() {
        // The phone-side code branches on this nil and writes empty
        // strings into the dict instead. Verifying nil here is
        // verifying the upstream branch.
        let block = TrainingBlock(startDate: day(0), weekCount: 4, phase: .accumulate)
        XCTAssertNil(TrainingBlockEngine.currentBlock(in: [block], at: day(40)),
                     "Gap after a block: phone writes empty strings to the dict")
    }

    func testEmptyBlocksReturnsNil() {
        XCTAssertNil(TrainingBlockEngine.currentBlock(in: [], at: day(0)),
                     "No history: phone writes empty strings to the dict")
    }

    // MARK: - Dictionary survival

    /// Simulates what WCSession does with the application-context
    /// dict — round-trips through JSON so we catch any payload-shape
    /// regressions (e.g. accidentally putting a non-Codable type in
    /// the dict).
    func testBlockKeysSurviveJSONRoundTrip() throws {
        let dict: [String: Any] = [
            WatchMessageKey.blockPhase: "deload",
            WatchMessageKey.blockWeekLabel: "Week 1 of 1"
        ]
        let data = try JSONSerialization.data(withJSONObject: dict)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(decoded?[WatchMessageKey.blockPhase] as? String, "deload")
        XCTAssertEqual(decoded?[WatchMessageKey.blockWeekLabel] as? String, "Week 1 of 1")
    }

    func testEmptyStringSentinelSurvivesRoundTrip() throws {
        // The "no active block" sentinel is `""` (empty string), not
        // a missing key. The watch reader checks `.isEmpty` to drop
        // the periodisation strip. Empty strings must survive the
        // serialization round-trip rather than getting dropped to
        // nil.
        let dict: [String: Any] = [
            WatchMessageKey.blockPhase: "",
            WatchMessageKey.blockWeekLabel: ""
        ]
        let data = try JSONSerialization.data(withJSONObject: dict)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(decoded?[WatchMessageKey.blockPhase] as? String, "",
                       "Empty-string sentinel must round-trip — never gets dropped to nil")
        XCTAssertEqual(decoded?[WatchMessageKey.blockWeekLabel] as? String, "")
    }
}
