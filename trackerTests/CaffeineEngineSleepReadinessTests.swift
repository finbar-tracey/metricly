import XCTest
@testable import tracker

final class CaffeineEngineSleepReadinessTests: XCTestCase {

    func testSleepReadinessThresholds() {
        XCTAssertEqual(CaffeineEngine.SleepReadiness.level(forMg: 10), .readyForSleep)
        XCTAssertEqual(CaffeineEngine.SleepReadiness.level(forMg: 40), .windingDown)
        XCTAssertEqual(CaffeineEngine.SleepReadiness.level(forMg: 75), .elevated)
        XCTAssertEqual(CaffeineEngine.SleepReadiness.level(forMg: 150), .tooStimulated)
    }
}
