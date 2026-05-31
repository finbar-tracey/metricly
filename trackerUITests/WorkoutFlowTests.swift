import XCTest

final class WorkoutFlowTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTrainingTabOpensSeededWorkoutDetail() throws {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: ["-skipOnboarding", "-UITests", "-seedDemoWorkout"])
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))

        let trainingTab = app.tabBars.buttons["Training"]
        if trainingTab.waitForExistence(timeout: 3) {
            trainingTab.tap()
        } else {
            app.tabBars.buttons.element(boundBy: 1).tap()
        }

        let workoutLink = app.staticTexts["UITest Push"]
        if workoutLink.waitForExistence(timeout: 5) {
            workoutLink.tap()
        } else if app.cells.firstMatch.waitForExistence(timeout: 5) {
            app.cells.firstMatch.tap()
        }

        XCTAssertTrue(
            app.navigationBars["UITest Push"].waitForExistence(timeout: 8)
                || app.buttons["Finish workout"].waitForExistence(timeout: 8)
                || app.staticTexts["Exercises"].waitForExistence(timeout: 8)
        )

        let finishButton = app.buttons["Finish workout"]
        if finishButton.waitForExistence(timeout: 3) {
            finishButton.tap()
            XCTAssertTrue(
                app.navigationBars["Workout Complete"].waitForExistence(timeout: 5)
                    || app.buttons["Done"].waitForExistence(timeout: 5)
            )
            let cancel = app.buttons["Cancel"]
            if cancel.waitForExistence(timeout: 2) {
                cancel.tap()
            }
        }
    }
}
