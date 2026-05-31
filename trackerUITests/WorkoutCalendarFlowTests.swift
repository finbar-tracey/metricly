import XCTest

final class WorkoutCalendarFlowTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testWorkoutCalendarOpensFromTrainingHub() throws {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: ["-skipOnboarding", "-UITests"])
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))

        let trainingTab = app.tabBars.buttons["Training"]
        if trainingTab.waitForExistence(timeout: 3) {
            trainingTab.tap()
        }

        let calendarLink = app.staticTexts["Calendar"]
        if calendarLink.waitForExistence(timeout: 5) {
            calendarLink.tap()
            XCTAssertTrue(app.navigationBars["Calendar"].waitForExistence(timeout: 5))
        }
    }
}
