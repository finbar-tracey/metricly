import XCTest
@testable import tracker

final class StravaTokenRefresherTests: XCTestCase {

    func testRefreshFailureThrows() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.handler = { _ in
            (HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
        }
        let session = URLSession(configuration: config)
        let refresher = StravaTokenRefresher(
            clientID: "id",
            clientSecret: "secret",
            session: session
        )

        do {
            _ = try await refresher.refresh(refreshToken: "rt")
            XCTFail("Expected refreshFailed")
        } catch let error as StravaError {
            guard case .refreshFailed = error else {
                XCTFail("Expected refreshFailed, got \(error)")
                return
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRefreshSuccessPreservesAthlete() async throws {
        let json = """
        {"access_token":"new","refresh_token":"newrt","expires_at":9999999999}
        """.data(using: .utf8)!
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.handler = { _ in
            let response = HTTPURLResponse(
                url: URL(string: "https://www.strava.com/api/v3/oauth/token")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json)
        }
        let session = URLSession(configuration: config)
        let existing = StravaTokenStore.Tokens(
            accessToken: "old",
            refreshToken: "rt",
            expiresAt: 0,
            athleteID: 42,
            athleteFirstName: "Ada",
            athleteLastName: "Lovelace"
        )
        let refresher = StravaTokenRefresher(
            clientID: "id",
            clientSecret: "secret",
            session: session,
            preserveAthleteFrom: existing
        )
        let tokens = try await refresher.refresh(refreshToken: "rt")
        XCTAssertEqual(tokens.accessToken, "new")
        XCTAssertEqual(tokens.athleteID, 42)
        XCTAssertEqual(tokens.athleteFirstName, "Ada")
    }
}

private final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (URLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
