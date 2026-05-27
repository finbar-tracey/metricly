import XCTest
@testable import tracker
import SwiftData

/// Tests for RecoveryEngine's third intensity signal: user-reported
/// muscle soreness. Stacks multiplicatively on top of the model's
/// per-muscle freshness output, so a user saying "my legs are sore"
/// drops legs freshness regardless of what volume/RPE estimate.
@MainActor
final class RecoveryEngineSorenessTests: XCTestCase {

    private let container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: SorenessEntry.self, configurations: config)
    }()

    private func entry(_ group: MuscleGroup, _ level: Int, hoursAgo: Double = 1) -> SorenessEntry {
        SorenessEntry(
            date: Date.now.addingTimeInterval(-hoursAgo * 3600),
            group: group,
            level: level
        )
    }

    // MARK: - Baselines

    func testNoReportsLeavesFreshnessUnchanged() {
        // With no workouts and no reports, every group reads as fully fresh.
        let result = RecoveryEngine.evaluate(workouts: [], sorenessReports: [])
        for muscle in result.muscleResults {
            XCTAssertEqual(muscle.freshness, 1.0, accuracy: 0.001,
                           "Group \(muscle.group) should be fully fresh")
        }
    }

    func testLevelZeroReportHasNoEffect() {
        let report = entry(.legs, 0)
        let result = RecoveryEngine.evaluate(workouts: [], sorenessReports: [report])
        let legs = result.muscleResults.first(where: { $0.group == .legs })
        XCTAssertEqual(legs?.freshness, 1.0, accuracy: 0.001)
    }

    // MARK: - Per-group impact

    func testHighLevelReportLowersOnlyTargetedGroup() {
        let result = RecoveryEngine.evaluate(
            workouts: [],
            sorenessReports: [entry(.legs, 4)]
        )
        let legs  = result.muscleResults.first { $0.group == .legs }
        let chest = result.muscleResults.first { $0.group == .chest }
        XCTAssertNotNil(legs)
        XCTAssertNotNil(chest)
        // Level 4 with default 0.075 step → 1 - 4*0.075 = 0.7
        XCTAssertEqual(legs!.freshness, 0.7, accuracy: 0.001)
        // Other groups untouched
        XCTAssertEqual(chest!.freshness, 1.0, accuracy: 0.001)
    }

    func testEachLevelProducesExpectedMultiplier() {
        let step = EngineConstants.Recovery.sorenessLevelStep
        for level in 0...4 {
            let result = RecoveryEngine.evaluate(
                workouts: [],
                sorenessReports: [entry(.chest, level)]
            )
            let chest = result.muscleResults.first(where: { $0.group == .chest })
            let expected = level == 0 ? 1.0 : (1.0 - Double(level) * step)
            XCTAssertEqual(chest?.freshness ?? 0, expected, accuracy: 0.001,
                           "Level \(level) should produce \(expected)× freshness")
        }
    }

    // MARK: - Recency

    func testStaleReportIsIgnored() {
        // 50h > 48h lookback default — should be dropped.
        let stale = entry(.legs, 4, hoursAgo: 50)
        let result = RecoveryEngine.evaluate(workouts: [], sorenessReports: [stale])
        let legs = result.muscleResults.first(where: { $0.group == .legs })
        XCTAssertEqual(legs?.freshness, 1.0, accuracy: 0.001,
                       "Reports older than the lookback shouldn't affect freshness")
    }

    func testFutureDatedReportIsIgnored() {
        // Defensive: a report dated 1h into the future (clock drift) — skip.
        let future = SorenessEntry(date: Date.now.addingTimeInterval(3600), group: .legs, level: 4)
        let result = RecoveryEngine.evaluate(workouts: [], sorenessReports: [future])
        let legs = result.muscleResults.first(where: { $0.group == .legs })
        XCTAssertEqual(legs?.freshness, 1.0, accuracy: 0.001)
    }

    func testMostRecentReportWinsWhenMultiplePresent() {
        // Older report = severe, newer report = mild — newer should apply.
        let older = entry(.legs, 4, hoursAgo: 24)
        let newer = entry(.legs, 1, hoursAgo: 1)
        let result = RecoveryEngine.evaluate(
            workouts: [],
            sorenessReports: [older, newer]
        )
        let legs = result.muscleResults.first(where: { $0.group == .legs })
        let expected = 1.0 - 1.0 * EngineConstants.Recovery.sorenessLevelStep
        XCTAssertEqual(legs?.freshness ?? 0, expected, accuracy: 0.001)
    }

    // MARK: - Defensive bounds

    func testNegativeLevelIsClamped() {
        // Shouldn't happen via the UI but defensive against bad data.
        let bad = SorenessEntry(date: .now, group: .chest, level: -3)
        let result = RecoveryEngine.evaluate(workouts: [], sorenessReports: [bad])
        let chest = result.muscleResults.first(where: { $0.group == .chest })
        XCTAssertEqual(chest?.freshness, 1.0, accuracy: 0.001)
    }

    func testLevelAboveMaxIsClamped() {
        let bad = SorenessEntry(date: .now, group: .chest, level: 99)
        let result = RecoveryEngine.evaluate(workouts: [], sorenessReports: [bad])
        let chest = result.muscleResults.first(where: { $0.group == .chest })
        // Clamped to 4, so 1 - 4*step
        let expected = 1.0 - 4.0 * EngineConstants.Recovery.sorenessLevelStep
        XCTAssertEqual(chest?.freshness ?? 0, expected, accuracy: 0.001)
    }
}
