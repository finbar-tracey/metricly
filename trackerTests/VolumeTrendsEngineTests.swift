import XCTest
@testable import tracker

final class VolumeTrendsEngineTests: XCTestCase {

    func testVolumeChangePercent() {
        XCTAssertEqual(VolumeTrendsEngine.volumeChangePercent(thisWeek: 110, lastWeek: 100), 10, accuracy: 0.01)
        XCTAssertEqual(VolumeTrendsEngine.volumeChangePercent(thisWeek: 50, lastWeek: 0), 0)
    }

    func testFormatVolumeKg() {
        let formatted = VolumeTrendsEngine.formatVolume(500, unit: .kg)
        XCTAssertTrue(formatted.contains("kg"))
    }
}
