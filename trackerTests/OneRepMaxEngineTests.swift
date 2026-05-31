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
}
