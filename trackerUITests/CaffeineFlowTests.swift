import XCTest

final class CaffeineFlowTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCaffeineLogButtonExistsOnNutritionPath() throws {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: ["-skipOnboarding", "-UITests"])
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))

        let moreTab = app.tabBars.buttons["More"]
        if moreTab.waitForExistence(timeout: 3) {
            moreTab.tap()
        } else {
            app.tabBars.buttons.element(boundBy: app.tabBars.buttons.count - 1).tap()
        }

        let caffeineLink = app.staticTexts["Caffeine"]
        if caffeineLink.waitForExistence(timeout: 5) {
            caffeineLink.tap()
        } else if app.buttons["Caffeine"].waitForExistence(timeout: 3) {
            app.buttons["Caffeine"].tap()
        }

        let logButton = app.buttons["caffeineLogButton"]
        XCTAssertTrue(
            logButton.waitForExistence(timeout: 8)
                || app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Log'")).firstMatch.waitForExistence(timeout: 3)
        )
    }
}
