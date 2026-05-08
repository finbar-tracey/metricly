import XCTest
@testable import tracker

final class HealthFormattersTests: XCTestCase {

    // MARK: - formatSteps

    func testStepsWithThousandsSeparator() {
        // NumberFormatter applies the user's locale separator. Just verify
        // the digits are present in order (locale-agnostic check).
        let result = HealthFormatters.formatSteps(12_345)
        XCTAssertTrue(result.contains("12") && result.contains("345"))
    }

    func testZeroSteps() {
        XCTAssertEqual(HealthFormatters.formatSteps(0), "0")
    }

    func testStepsRoundsDownFractional() {
        // formatSteps takes Double but produces integer output
        let result = HealthFormatters.formatSteps(1234.7)
        XCTAssertFalse(result.contains("."))
    }

    // MARK: - formatSleepShort

    func testSleepShortDashWhenZero() {
        XCTAssertEqual(HealthFormatters.formatSleepShort(0), "—")
    }

    func testSleepShortMinutesOnly() {
        XCTAssertEqual(HealthFormatters.formatSleepShort(45), "45m")
    }

    func testSleepShortFullHours() {
        XCTAssertEqual(HealthFormatters.formatSleepShort(120), "2h")
    }

    func testSleepShortHoursAndMinutes() {
        // 7h 30m
        XCTAssertEqual(HealthFormatters.formatSleepShort(450), "7h 30m")
    }

    // MARK: - formatDistance (km-only legacy)

    func testFormatDistanceShortReturnsEmDashBelowThreshold() {
        XCTAssertEqual(HealthFormatters.formatDistance(0.005), "—")
    }

    func testFormatDistanceKmDefault() {
        XCTAssertEqual(HealthFormatters.formatDistance(5.0), "5.0 km")
    }

    // MARK: - formatDistance with unit

    func testFormatDistanceInMiles() {
        // 10 km ≈ 6.2 mi
        let result = HealthFormatters.formatDistance(10.0, unit: .mi)
        XCTAssertTrue(result.hasSuffix(" mi"))
        XCTAssertTrue(result.hasPrefix("6"))
    }

    func testFormatDistanceInKmExplicit() {
        XCTAssertEqual(HealthFormatters.formatDistance(7.5, unit: .km), "7.5 km")
    }

    func testFormatDistanceWithUnitTinyValue() {
        XCTAssertEqual(HealthFormatters.formatDistance(0.001, unit: .km), "—")
        XCTAssertEqual(HealthFormatters.formatDistance(0.001, unit: .mi), "—")
    }

    // MARK: - formatCalories

    func testCaloriesZero() {
        XCTAssertEqual(HealthFormatters.formatCalories(0), "0 kcal")
    }

    func testCaloriesRoundsToInteger() {
        XCTAssertTrue(HealthFormatters.formatCalories(345.7).hasSuffix(" kcal"))
        XCTAssertFalse(HealthFormatters.formatCalories(345.7).contains("."))
    }

    // MARK: - formatSleepDuration (long form, used in accessibility labels)

    func testSleepDurationLongForm() {
        XCTAssertEqual(HealthFormatters.formatSleepDuration(450), "7 hours 30 minutes")
        XCTAssertEqual(HealthFormatters.formatSleepDuration(60), "1 hours 0 minutes")
    }
}
