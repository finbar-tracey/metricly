import XCTest
@testable import tracker

final class OneRepMaxEngineTests: XCTestCase {

    func testEpleySingleRepReturnsWeight() {
        let e1rm = OneRepMaxEngine.Formula.epley.calculate(weight: 100, reps: 1)
        XCTAssertEqual(e1rm, 100, accuracy: 0.01)
    }

    func testEpleyFiveReps() {
        let e1rm = OneRepMaxEngine.Formula.epley.calculate(weight: 100, reps: 5)
        XCTAssertEqual(e1rm, 116.67, accuracy: 0.1)
    }

    func testPercentageRows() {
        let rows = OneRepMaxEngine.percentageRows(base: 200)
        XCTAssertEqual(rows.count, 9)
        XCTAssertEqual(rows.first?.label, "100%")
        XCTAssertEqual(rows.first?.value ?? 0, 200, accuracy: 0.01)
    }

    func testEpleyEstimateMatchesFormula() {
        XCTAssertEqual(
            OneRepMaxEngine.epleyEstimate(weight: 80, reps: 5),
            OneRepMaxEngine.Formula.epley.calculate(weight: 80, reps: 5),
            accuracy: 0.01
        )
    }

    func testBrzyckiNormalRange() {
        // 100 × 36 / (37 − 5) = 112.5
        let e1rm = OneRepMaxEngine.Formula.brzycki.calculate(weight: 100, reps: 5)
        XCTAssertEqual(e1rm, 112.5, accuracy: 0.01)
    }

    func testBrzyckiHighRepsStayFiniteAndPositive() {
        // Reps ≥ 37 must not divide by zero or go negative — falls back to Epley.
        for reps in [37, 40, 60, 100] {
            let e1rm = OneRepMaxEngine.Formula.brzycki.calculate(weight: 100, reps: reps)
            XCTAssertTrue(e1rm.isFinite, "reps \(reps) produced non-finite 1RM")
            XCTAssertGreaterThan(e1rm, 0, "reps \(reps) produced non-positive 1RM")
            XCTAssertEqual(e1rm, OneRepMaxEngine.Formula.epley.calculate(weight: 100, reps: reps), accuracy: 0.01)
        }
    }
}
