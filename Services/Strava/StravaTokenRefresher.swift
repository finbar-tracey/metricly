import Foundation

/// OAuth token refresh for Strava (injectable `URLSession` for tests).
struct StravaTokenRefresher: Sendable {
    let clientID: String
    let clientSecret: String
    let session: URLSession
    var preserveAthleteFrom: StravaTokenStore.Tokens?

    func refresh(refreshToken: String) async throws -> StravaTokenStore.Tokens {
        var request = URLRequest(url: URL(string: "https://www.strava.com/api/v3/oauth/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "client_id": clientID,
            "client_secret": clientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        // Reuse the shared form encoder — `.urlQueryAllowed` does not escape
        // `+`/`&`/`=`, which corrupt an x-www-form-urlencoded body.
        request.httpBody = StravaAPIClient.formEncode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw StravaError.noResponse
        }
        guard (200...299).contains(http.statusCode) else {
            // 400/401 = refresh token rejected (revoked/invalid): caller should
            // disconnect. Anything else (5xx, 429) is treated as transient.
            if http.statusCode == 400 || http.statusCode == 401 {
                throw StravaError.refreshFailed
            }
            throw StravaError.httpFailure(status: http.statusCode, body: "")
        }
        let decoded = try JSONDecoder().decode(RefreshTokenResponse.self, from: data)
        return StravaTokenStore.Tokens(
            accessToken: decoded.access_token,
            refreshToken: decoded.refresh_token,
            expiresAt: decoded.expires_at,
            athleteID: preserveAthleteFrom?.athleteID,
            athleteFirstName: preserveAthleteFrom?.athleteFirstName,
            athleteLastName: preserveAthleteFrom?.athleteLastName
        )
    }
}

private struct RefreshTokenResponse: Decodable {
    let access_token: String
    let refresh_token: String
    let expires_at: TimeInterval
}
