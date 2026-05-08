import XCTest
@testable import tracker

final class UnitsTests: XCTestCase {

    // MARK: - WeightUnit conversions

    func testKilogramsAreIdentity() {
        XCTAssertEqual(WeightUnit.kg.display(100), 100)
        XCTAssertEqual(WeightUnit.kg.toKg(100), 100)
    }

    func testPoundsConversionRoundTrip() {
        let kg = 80.0
        let lbs = WeightUnit.lbs.display(kg)
        let back = WeightUnit.lbs.toKg(lbs)
        XCTAssertEqual(back, kg, accuracy: 0.001)
    }

    func testPoundsDisplayMatchesExpectedValue() {
        // 100 kg ≈ 220.46 lbs
        XCTAssertEqual(WeightUnit.lbs.display(100), 220.462, accuracy: 0.01)
    }

    func testPoundsToKgConversion() {
        // 220 lbs ≈ 99.79 kg
        XCTAssertEqual(WeightUnit.lbs.toKg(220), 99.79, accuracy: 0.01)
    }

    // MARK: - WeightUnit formatting

    func testKgFormat() {
        XCTAssertEqual(WeightUnit.kg.format(80.0), "80.0 kg")
        XCTAssertEqual(WeightUnit.kg.formatShort(80.0), "80kg")
    }

    func testLbsFormat() {
        let formatted = WeightUnit.lbs.format(100)
        XCTAssertTrue(formatted.hasSuffix(" lbs"))
        XCTAssertTrue(formatted.hasPrefix("220"))
    }

    // MARK: - DistanceUnit conversions

    func testKmIsIdentity() {
        XCTAssertEqual(DistanceUnit.km.display(5), 5)
        XCTAssertEqual(DistanceUnit.km.toKm(5), 5)
    }

    func testMilesConversionRoundTrip() {
        let km = 10.0
        let mi = DistanceUnit.mi.display(km)
        let back = DistanceUnit.mi.toKm(mi)
        XCTAssertEqual(back, km, accuracy: 0.001)
    }

    func testMilesDisplayMatchesExpectedValue() {
        // 10 km ≈ 6.21 miles
        XCTAssertEqual(DistanceUnit.mi.display(10), 6.21371, accuracy: 0.001)
    }

    // MARK: - DistanceUnit formatting

    func testKmFormatBelowOne() {
        // Sub-kilometre values formatted as metres
        XCTAssertEqual(DistanceUnit.km.format(0.5), "500 m")
        XCTAssertEqual(DistanceUnit.km.format(0.123), "123 m")
    }

    func testKmFormatAboveOne() {
        XCTAssertEqual(DistanceUnit.km.format(5.0), "5.00 km")
        XCTAssertEqual(DistanceUnit.km.format(10.5), "10.50 km")
    }

    func testMilesFormatAlwaysDecimal() {
        // For miles we don't switch to metres at low values
        let result = DistanceUnit.mi.format(0.5)
        XCTAssertTrue(result.hasSuffix(" mi"))
    }

    func testStepSize() {
        XCTAssertEqual(DistanceUnit.km.stepSize, 0.5)
        XCTAssertEqual(DistanceUnit.mi.stepSize, 0.25)
    }

    // MARK: - WeightUnit ↔ DistanceUnit pairing

    func testKgPairsWithKm() {
        XCTAssertEqual(WeightUnit.kg.distanceUnit, .km)
    }

    func testLbsPairsWithMiles() {
        XCTAssertEqual(WeightUnit.lbs.distanceUnit, .mi)
    }

    // MARK: - Labels

    func testLabels() {
        XCTAssertEqual(WeightUnit.kg.label, "kg")
        XCTAssertEqual(WeightUnit.lbs.label, "lbs")
        XCTAssertEqual(DistanceUnit.km.label, "km")
        XCTAssertEqual(DistanceUnit.mi.label, "mi")
    }
}
