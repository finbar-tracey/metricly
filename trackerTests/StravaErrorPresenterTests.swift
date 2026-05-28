import XCTest
@testable import tracker

/// Tests for `StravaErrorPresenter` — the lifted-out version of the
/// status-code → user-message mapping that used to live inline in
/// `StravaSettingsSection`'s catch chain.
///
/// We pin the **classification** (`Reason`) explicitly so a swapped 401
/// / 429 branch breaks the test, and we assert the **kind** because
/// that drives the banner colour (warning amber vs failure red). We do
/// NOT assert the literal English message text — that's expected to
/// drift with localization edits.
final class StravaErrorPresenterTests: XCTestCase {

    private func present(_ status: Int) -> StravaErrorPresenter.Presentation {
        StravaErrorPresenter.present(
            StravaError.httpFailure(status: status, body: "")
        )
    }

    // MARK: - 401: stale-scope reconnect prompt

    func test401MapsToTokenScopeStaleWarning() {
        let p = present(401)
        XCTAssertEqual(p.reason, .tokenScopeStale)
        XCTAssertEqual(p.kind, .warning,
                       "Reconnect prompts are actionable — warning, not failure")
        XCTAssertFalse(p.message.isEmpty)
    }

    // MARK: - 429: rate limit

    func test429MapsToRateLimitedWarning() {
        let p = present(429)
        XCTAssertEqual(p.reason, .rateLimited)
        XCTAssertEqual(p.kind, .warning,
                       "Rate-limit is recoverable; should not show as failure red")
        XCTAssertFalse(p.message.isEmpty)
    }

    // MARK: - Generic fall-through

    func test500MapsToGenericFailure() {
        let p = present(500)
        XCTAssertEqual(p.reason, .generic)
        XCTAssertEqual(p.kind, .failure)
        XCTAssertFalse(p.message.isEmpty)
    }

    func test404MapsToGenericFailure() {
        // Not specially handled — falls through to generic.
        let p = present(404)
        XCTAssertEqual(p.reason, .generic)
        XCTAssertEqual(p.kind, .failure)
    }

    func testNonHTTPStravaErrorMapsToGeneric() {
        // A token-store error or auth flow error that isn't an httpFailure
        // should still produce a banner — the user shouldn't see silence.
        let p = StravaErrorPresenter.present(StravaError.notConnected)
        XCTAssertEqual(p.reason, .generic)
        XCTAssertEqual(p.kind, .failure)
        XCTAssertFalse(p.message.isEmpty)
    }

    func testCompletelyUnrelatedErrorMapsToGeneric() {
        // A URLSession error, JSON decode error, etc. — the catch site
        // in StravaSettingsSection used to handle these via the bare
        // `catch` arm. Same outcome here.
        struct Unrelated: Error {}
        let p = StravaErrorPresenter.present(Unrelated())
        XCTAssertEqual(p.reason, .generic)
        XCTAssertEqual(p.kind, .failure)
        XCTAssertFalse(p.message.isEmpty)
    }

    // MARK: - Anti-swap regression

    func test401And429ProduceDistinctMessages() {
        // Catches the specific regression where someone swaps the 401
        // and 429 catch arms — kinds would both stay .warning but the
        // user gets the wrong recovery instruction.
        let four01 = present(401)
        let four29 = present(429)
        XCTAssertNotEqual(four01.reason, four29.reason)
        XCTAssertNotEqual(four01.message, four29.message,
                          "401 reconnect copy must not match 429 rate-limit copy")
    }
}
