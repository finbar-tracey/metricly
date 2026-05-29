import XCTest
@testable import tracker

/// Pins `StravaService.formEncode(_:)` — the
/// `application/x-www-form-urlencoded` body encoder shared by the OAuth
/// token endpoints and the activity upload/update endpoints.
///
/// The encoder replaces the original `.urlQueryAllowed` call, which is
/// the character set for URL *query strings*, not form bodies. With
/// the old encoding, an activity name like "Run & Ride" would have
/// emitted `name=Run & Ride` — splitting the form into two key/value
/// pairs at the `&` and corrupting the request. These tests pin the
/// fix and the convention (spaces → `+`, reserved characters
/// percent-encoded).
///
/// The encoder produces a single `application/x-www-form-urlencoded`
/// string; dictionary ordering isn't guaranteed so tests split on `&`
/// and compare key/value pairs as a set.
final class StravaFormEncoderTests: XCTestCase {

    private func encodedPairs(_ body: [String: String]) -> Set<String> {
        let data = StravaService.formEncode(body) ?? Data()
        let string = String(data: data, encoding: .utf8) ?? ""
        return Set(string.split(separator: "&").map(String.init))
    }

    // MARK: - Baseline

    func testEmptyBodyProducesEmptyOutput() {
        let data = StravaService.formEncode([:]) ?? Data()
        XCTAssertEqual(data.count, 0)
    }

    func testSimpleAlphanumericPairsAreUnchanged() {
        let pairs = encodedPairs(["client_id": "12345", "grant_type": "refresh_token"])
        XCTAssertEqual(pairs, ["client_id=12345", "grant_type=refresh_token"])
    }

    // MARK: - Form encoding contract

    func testSpacesEncodeAsPlus() {
        // The `application/x-www-form-urlencoded` spec encodes spaces as
        // `+`. URL queries use `%20`; this is the one place where they
        // diverge and the old `.urlQueryAllowed` path got it wrong.
        let pairs = encodedPairs(["name": "Morning Run"])
        XCTAssertEqual(pairs, ["name=Morning+Run"])
    }

    func testAmpersandInValueIsPercentEncoded() {
        // The regression case. With `.urlQueryAllowed`, "Run & Ride"
        // emitted as `name=Run & Ride` and the server saw two keys
        // (`name`, ` Ride`). The fix percent-encodes the `&`.
        let pairs = encodedPairs(["name": "Run & Ride"])
        XCTAssertEqual(pairs, ["name=Run+%26+Ride"])
    }

    func testPlusInValueIsPercentEncoded() {
        // `+` in a form value MUST be percent-encoded — leaving it
        // literal would round-trip back as a space on the server.
        let pairs = encodedPairs(["sport_type": "C++ run"])
        XCTAssertEqual(pairs, ["sport_type=C%2B%2B+run"])
    }

    func testEqualsInValueIsPercentEncoded() {
        // `=` separates key from value; an unencoded `=` in a value
        // would shift the parser's understanding of the boundary.
        let pairs = encodedPairs(["description": "a=b"])
        XCTAssertEqual(pairs, ["description=a%3Db"])
    }

    func testEqualsInKeyIsPercentEncoded() {
        // Same concern but on the key side — defensive; we never
        // actually pass `=` in a key, but the encoder should still be
        // correct in case a future call site does.
        let pairs = encodedPairs(["a=b": "c"])
        XCTAssertEqual(pairs, ["a%3Db=c"])
    }

    func testQuestionMarkAndHashArePercentEncoded() {
        // Neither has special meaning inside a request body, but the
        // strict unreserved character set encodes both. Pin the
        // behaviour so a future loosening that drops them doesn't go
        // unnoticed.
        let pairs = encodedPairs(["q": "what?", "anchor": "top#1"])
        XCTAssertEqual(pairs, ["q=what%3F", "anchor=top%231"])
    }

    func testUnreservedCharactersAreNotEncoded() {
        // RFC 3986's unreserved set — alphanumeric plus `-._~` — must
        // pass through literally. The form encoder previously erred on
        // the side of encoding too much (e.g. `.` percent-encoded
        // showed up as `%2E`).
        let pairs = encodedPairs(["mix": "a-b._~1"])
        XCTAssertEqual(pairs, ["mix=a-b._~1"])
    }

    // MARK: - Real-world Strava bodies

    func testTokenRefreshBodyEncodesCleanly() {
        // The actual token-refresh POST body shape. Smoke test that the
        // realistic combination of fields produces parseable output.
        let pairs = encodedPairs([
            "client_id":     "12345",
            "client_secret": "abcdef1234567890",
            "grant_type":    "refresh_token",
            "refresh_token": "1234abcd",
        ])
        XCTAssertEqual(pairs.count, 4)
        XCTAssertTrue(pairs.contains("client_id=12345"))
        XCTAssertTrue(pairs.contains("grant_type=refresh_token"))
    }

    func testActivityUploadWithTrickyNameEncodesCleanly() {
        // Real-world: a user's activity name with reserved chars and
        // spaces. Round-trip-decode the result and confirm we get back
        // the original — the definitive correctness check.
        let original = "Morning Run & Stretch (5+ km)"
        let data = StravaService.formEncode(["name": original]) ?? Data()
        let string = String(data: data, encoding: .utf8) ?? ""

        // Manual decode: split on '=', undo `+` → space, percent-decode.
        let parts = string.split(separator: "=", maxSplits: 1)
        XCTAssertEqual(parts.count, 2, "Form output must have a single = boundary per pair")
        let valueRaw = String(parts[1]).replacingOccurrences(of: "+", with: " ")
        let decoded = valueRaw.removingPercentEncoding ?? ""
        XCTAssertEqual(decoded, original,
                       "Form encoder must round-trip arbitrary names exactly")
    }
}
