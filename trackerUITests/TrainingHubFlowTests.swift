import XCTest

final class TrainingHubFlowTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTrainingTabShowsHubContent() throws {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: ["-skipOnboarding", "-UITests"])
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))

        let trainingTab = app.tabBars.buttons["Training"]
        if trainingTab.waitForExistence(timeout: 3) {
            trainingTab.tap()
        } else {
            app.tabBars.buttons.element(boundBy: 1).tap()
        }

        XCTAssertTrue(
            app.navigationBars["Training"].waitForExistence(timeout: 5)
                || app.staticTexts["Workouts"].waitForExistence(timeout: 5)
                || app.buttons["Start Workout"].waitForExistence(timeout: 5)
        )
    }
}
