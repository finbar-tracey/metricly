import XCTest
@testable import tracker

/// Tests for `PersonalInsightsEngine.blockPhaseVsSoreness` — the
/// physiological complement to the strength block insight. Answers
/// "are your deload weeks actually reducing reported soreness?"
///
/// Three contracts:
///
///   1. **Bucketing.** A report's date determines its bucket via
///      `TrainingBlockEngine.currentBlock(in:at:)`. Reports in gaps
///      drop out.
///   2. **Sample floors.** Need ≥3 reports per bucket.
///   3. **Direction + threshold.** Forward narrative (deload < acc
///      by ≥0.5 levels) reads as "Deload weeks ease your soreness".
///      Inverse (deload ≥ accumulate) reads as a warning. Sub-0.5
///      effect returns nil (silence).
@MainActor
final class BlockPhaseSorenessInsightTests: XCTestCase {

    private let cal = Calendar.current

    /// Pinned now — fixtures use offsets from this anchor so the
    /// 90-day wide-lookback always contains them.
    private static let now: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 4; c.day = 1
        return Calendar.current.date(from: c) ?? .distantPast
    }()

    private func day(daysAgo: Int) -> Date {
        cal.date(byAdding: .day, value: -daysAgo, to: BlockPhaseSorenessInsightTests.now)
            ?? BlockPhaseSorenessInsightTests.now
    }

    private func report(daysAgo: Int, level: Int, group: MuscleGroup = .chest) -> SorenessEntry {
        SorenessEntry(date: day(daysAgo: daysAgo), group: group, level: level)
    }

    private func block(startedDaysAgo: Int, weeks: Int, phase: TrainingBlock.Phase) -> TrainingBlock {
        TrainingBlock(startDate: day(daysAgo: startedDaysAgo), weekCount: weeks, phase: phase)
    }

    private func generate(reports: [SorenessEntry], blocks: [TrainingBlock]) -> [Insight] {
        let inputs = PersonalInsightsEngine.Inputs(
            trainingBlocks: blocks,
            sorenessReports: reports,
            now: BlockPhaseSorenessInsightTests.now
        )
        // Inputs uses keyword args in any order — passing only what we
        // care about so the rest stays at defaults (empty arrays).
        return PersonalInsightsEngine.generate(inputs)
    }

    private func extract(_ insights: [Insight]) -> Insight? {
        insights.first { $0.category == .recovery && $0.icon == "figure.cooldown" }
    }

    // MARK: - Bucketing + forward narrative

    func testDeloadLowerThanAccumulateProducesReliefNarrative() {
        // 4-week accumulate at high soreness (avg 3.0), 1-week deload
        // at low soreness (avg 1.0) — clear delta of 2.0 on the 0-4
        // scale. Should produce the "easing" narrative.
        let blocks = [
            block(startedDaysAgo: 56, weeks: 4, phase: .accumulate),
            block(startedDaysAgo: 28, weeks: 1, phase: .deload),
            block(startedDaysAgo: 21, weeks: 3, phase: .accumulate),
        ]
        var reports: [SorenessEntry] = []
        // Accumulate (high soreness)
        for (offset, level) in [(40, 3), (36, 3), (32, 3), (50, 3)] {
            reports.append(report(daysAgo: offset, level: level))
        }
        // Deload (low soreness) — 4 reports so the total of 12 hits
        // the strong-tier sample threshold.
        for (offset, level) in [(27, 1), (25, 1), (23, 1), (24, 1)] {
            reports.append(report(daysAgo: offset, level: level))
        }
        // Second accumulate (high again)
        for (offset, level) in [(18, 3), (14, 3), (7, 3), (3, 3)] {
            reports.append(report(daysAgo: offset, level: level))
        }

        let insight = extract(generate(reports: reports, blocks: blocks))
        XCTAssertNotNil(insight)
        XCTAssertEqual(insight?.title, "Deload weeks ease your soreness")
        XCTAssertEqual(insight?.strength, .strong,
                       "0.7+ delta on 12+ reports → strong tier")
    }

    func testDeloadSameAsAccumulateProducesOverreachWarning() {
        // Deload at same soreness level as accumulate — no
        // physiological recovery happening even though the volume
        // dropped. Should suggest lengthening the deload.
        let blocks = [
            block(startedDaysAgo: 56, weeks: 4, phase: .accumulate),
            block(startedDaysAgo: 28, weeks: 1, phase: .deload),
            block(startedDaysAgo: 21, weeks: 3, phase: .accumulate),
        ]
        var reports: [SorenessEntry] = []
        // Accumulate (low soreness, surprising)
        for (offset, level) in [(40, 1), (36, 1), (32, 1), (50, 1)] {
            reports.append(report(daysAgo: offset, level: level))
        }
        // Deload (HIGH soreness — body isn't recovering on this rhythm)
        for (offset, level) in [(27, 3), (25, 3), (23, 3)] {
            reports.append(report(daysAgo: offset, level: level))
        }
        for (offset, level) in [(18, 1), (14, 1), (7, 1), (3, 1)] {
            reports.append(report(daysAgo: offset, level: level))
        }

        let insight = extract(generate(reports: reports, blocks: blocks))
        XCTAssertNotNil(insight)
        XCTAssertEqual(insight?.title, "Deload weeks aren't easing soreness")
        XCTAssertTrue(insight?.message.contains("lengthening your deload") == true
                      || insight?.message.contains("cutting volume") == true,
                      "Inverse narrative should suggest a periodisation adjustment")
    }

    func testReportsInGapsAreIgnored() {
        // Two blocks separated by a gap. Reports in the gap don't
        // belong to either bucket. With only 2 reports per real
        // bucket (below floor), the insight should not fire — proving
        // the gap reports didn't sneak in to pad either side.
        let blocks = [
            block(startedDaysAgo: 60, weeks: 4, phase: .accumulate),  // 60...32
            block(startedDaysAgo: 20, weeks: 1, phase: .deload),      // 20...13
        ]
        var reports: [SorenessEntry] = []
        for (offset, level) in [(50, 3), (40, 3)] {
            reports.append(report(daysAgo: offset, level: level))
        }
        // Gap window (28-21) — neither bucket should see these
        for (offset, level) in [(27, 2), (25, 2), (22, 2)] {
            reports.append(report(daysAgo: offset, level: level))
        }
        for (offset, level) in [(18, 1), (14, 1)] {
            reports.append(report(daysAgo: offset, level: level))
        }

        XCTAssertNil(extract(generate(reports: reports, blocks: blocks)),
                     "Gap reports must not pad either bucket — should stay below floor")
    }

    // MARK: - Sample / effect floors

    func testEmptyBlocksProducesNoInsight() {
        let reports: [SorenessEntry] = (1...10).map { report(daysAgo: $0, level: 2) }
        XCTAssertNil(extract(generate(reports: reports, blocks: [])))
    }

    func testEmptyReportsProducesNoInsight() {
        let blocks = [
            block(startedDaysAgo: 56, weeks: 4, phase: .accumulate),
            block(startedDaysAgo: 28, weeks: 1, phase: .deload),
        ]
        XCTAssertNil(extract(generate(reports: [], blocks: blocks)))
    }

    func testBelowEffectFloorReturnsNil() {
        // Average difference of 0.33 (3 accumulate at avg 2.33 vs 3
        // deload at avg 2.0). Below the 0.5-level effect floor.
        let blocks = [
            block(startedDaysAgo: 56, weeks: 4, phase: .accumulate),
            block(startedDaysAgo: 28, weeks: 1, phase: .deload),
            block(startedDaysAgo: 21, weeks: 3, phase: .accumulate),
        ]
        var reports: [SorenessEntry] = []
        // Accumulate avg = (2+2+3)/3 = 2.33
        for (offset, level) in [(40, 2), (36, 2), (32, 3)] {
            reports.append(report(daysAgo: offset, level: level))
        }
        // Deload avg = 2.0
        for (offset, level) in [(27, 2), (25, 2), (23, 2)] {
            reports.append(report(daysAgo: offset, level: level))
        }

        XCTAssertNil(extract(generate(reports: reports, blocks: blocks)),
                     "0.33-level delta is below the 0.5 effect floor — must stay silent")
    }

    func testTooFewDeloadReportsReturnsNil() {
        // Only 2 deload reports — below the 3-per-bucket floor.
        let blocks = [
            block(startedDaysAgo: 56, weeks: 4, phase: .accumulate),
            block(startedDaysAgo: 28, weeks: 1, phase: .deload),
        ]
        var reports: [SorenessEntry] = []
        for (offset, level) in [(50, 3), (40, 3), (32, 3), (35, 3)] {
            reports.append(report(daysAgo: offset, level: level))
        }
        for (offset, level) in [(27, 1), (25, 1)] {
            reports.append(report(daysAgo: offset, level: level))
        }
        XCTAssertNil(extract(generate(reports: reports, blocks: blocks)))
    }
}
