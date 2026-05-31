import XCTest
import SwiftData
@testable import tracker

final class BodyMeasurementsEngineTests: XCTestCase {

    func testChartYDomainPadding() {
        let domain = BodyMeasurementsEngine.chartYDomain(displayLengths: [30, 32, 31])
        XCTAssertLessThan(domain.lowerBound, 30)
        XCTAssertGreaterThan(domain.upperBound, 32)
    }

    func testSiteEntriesFilter() {
        let entries = [
            BodyMeasurement(date: .now, site: "Waist", value: 80),
            BodyMeasurement(date: .now, site: "Chest", value: 100),
        ]
        XCTAssertEqual(BodyMeasurementsEngine.siteEntries(allEntries: entries, site: "Waist").count, 1)
    }
}
