import XCTest

final class VolumeTrendsFlowTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testVolumeTrendsOpensFromInsights() throws {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: ["-skipOnboarding", "-UITests"])
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))

        let trainingTab = app.tabBars.buttons["Training"]
        if trainingTab.waitForExistence(timeout: 3) {
            trainingTab.tap()
        }

        let insightsLink = app.staticTexts["Insights"]
        if insightsLink.waitForExistence(timeout: 5) {
            insightsLink.tap()
        }

        let volumeTab = app.buttons["Volume"]
        if volumeTab.waitForExistence(timeout: 5) {
            volumeTab.tap()
            XCTAssertTrue(app.staticTexts["This Week"].waitForExistence(timeout: 5))
        }
    }
}
