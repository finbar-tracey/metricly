import XCTest
@testable import tracker

final class StravaTokenStoreTests: XCTestCase {

    override func tearDown() {
        StravaTokenStore.clear()
        super.tearDown()
    }

    func testSaveLoadRoundTrip() {
        let tokens = StravaTokenStore.Tokens(
            accessToken: "access-test",
            refreshToken: "refresh-test",
            expiresAt: Date.now.addingTimeInterval(3600).timeIntervalSince1970,
            athleteID: 42,
            athleteFirstName: "Test",
            athleteLastName: "Runner"
        )
        StravaTokenStore.save(tokens)
        let loaded = StravaTokenStore.load()
        XCTAssertEqual(loaded, tokens)
    }

    func testClearRemovesTokens() {
        StravaTokenStore.save(StravaTokenStore.Tokens(
            accessToken: "a",
            refreshToken: "r",
            expiresAt: Date.now.timeIntervalSince1970 + 100
        ))
        StravaTokenStore.clear()
        XCTAssertNil(StravaTokenStore.load())
    }

    func testIsExpiredWhenPastExpiry() {
        let expired = StravaTokenStore.Tokens(
            accessToken: "a",
            refreshToken: "r",
            expiresAt: Date.now.addingTimeInterval(-10).timeIntervalSince1970
        )
        XCTAssertTrue(expired.isExpired)
    }
}
