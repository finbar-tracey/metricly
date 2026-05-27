import XCTest
@testable import tracker

/// Tests for the pure-value validation that `LogBodyWeightIntent` /
/// `LogWaterIntent` call into before persisting. Live in their own file
/// so a UI/regression check on the rejection wording is a fast test,
/// not a Siri dry-run.
final class IntentValidatorsTests: XCTestCase {

    // MARK: - Body weight

    func testBodyWeightInsideRangeIsOK() {
        XCTAssertEqual(IntentValidators.bodyWeight(20), .ok)
        XCTAssertEqual(IntentValidators.bodyWeight(80.5), .ok)
        XCTAssertEqual(IntentValidators.bodyWeight(500), .ok)
    }

    func testBodyWeightZeroIsRejected() {
        guard case .invalid(let message) = IntentValidators.bodyWeight(0) else {
            return XCTFail("Expected invalid for 0 kg")
        }
        XCTAssertTrue(message.contains("0.0 kg"))
        XCTAssertTrue(message.contains("20 and 500"))
    }

    func testBodyWeightNegativeIsRejected() {
        guard case .invalid = IntentValidators.bodyWeight(-12) else {
            return XCTFail("Expected invalid for negative weight")
        }
    }

    func testBodyWeightAbsurdHighIsRejected() {
        guard case .invalid(let message) = IntentValidators.bodyWeight(800) else {
            return XCTFail("Expected invalid for 800 kg")
        }
        XCTAssertTrue(message.contains("800.0 kg"))
    }

    func testBodyWeightJustBelowBoundary() {
        // 19.9 kg → invalid; 20.0 kg → ok
        guard case .invalid = IntentValidators.bodyWeight(19.9) else {
            return XCTFail("Expected invalid just below lower bound")
        }
        XCTAssertEqual(IntentValidators.bodyWeight(20.0), .ok)
    }

    func testBodyWeightJustAboveBoundary() {
        // 500.0 kg → ok; 500.1 kg → invalid
        XCTAssertEqual(IntentValidators.bodyWeight(500.0), .ok)
        guard case .invalid = IntentValidators.bodyWeight(500.1) else {
            return XCTFail("Expected invalid just above upper bound")
        }
    }

    // MARK: - Water

    func testWaterInsideRangeIsOK() {
        XCTAssertEqual(IntentValidators.water(1), .ok)
        XCTAssertEqual(IntentValidators.water(250), .ok)
        XCTAssertEqual(IntentValidators.water(5000), .ok)
    }

    func testWaterZeroIsRejected() {
        guard case .invalid(let message) = IntentValidators.water(0) else {
            return XCTFail("Expected invalid for 0 ml")
        }
        XCTAssertTrue(message.contains("0 ml"))
        XCTAssertTrue(message.contains("1 and 5000"))
    }

    func testWaterNegativeIsRejected() {
        guard case .invalid = IntentValidators.water(-100) else {
            return XCTFail("Expected invalid for negative ml")
        }
    }

    func testWaterAbsurdHighIsRejected() {
        guard case .invalid(let message) = IntentValidators.water(10_000) else {
            return XCTFail("Expected invalid for 10,000 ml")
        }
        XCTAssertTrue(message.contains("10000 ml"))
    }

    func testWaterBoundaryValues() {
        XCTAssertEqual(IntentValidators.water(1), .ok)
        XCTAssertEqual(IntentValidators.water(5000), .ok)
        guard case .invalid = IntentValidators.water(0) else { return XCTFail("0 should be rejected") }
        guard case .invalid = IntentValidators.water(5001) else { return XCTFail("5001 should be rejected") }
    }
}
