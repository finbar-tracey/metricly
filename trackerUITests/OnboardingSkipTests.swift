import XCTest

final class OnboardingSkipTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testSkipOnboardingShowsTabBar() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-skipOnboarding")
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Welcome"].waitForExistence(timeout: 2))
    }
}
