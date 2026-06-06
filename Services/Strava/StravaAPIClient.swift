import Foundation

// MARK: - Errors

/// Network/types layer — explicitly nonisolated so URLSession work is not tied to MainActor.
enum StravaError: LocalizedError, Sendable {
    case notConnected
    case notConfigured
    case invalidURL
    case invalidCallback
    case stateMismatch
    case authorizationDenied(String)
    case couldNotStartAuth
    case noResponse
    case httpFailure(status: Int, body: String)
    case duplicateActivity
    case refreshFailed

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "You're not connected to Strava."
        case .notConfigured:
            return "Strava integration isn't set up in this build. See Config/Secrets.xcconfig.example."
        case .invalidURL:
            return "Internal: malformed Strava URL."
        case .invalidCallback:
            return "Strava sent an unexpected response. Try connecting again."
        case .stateMismatch:
            return "Strava sign-in didn't return safely. Try connecting again."
        case .authorizationDenied(let reason):
            return "Strava authorization failed: \(reason)"
        case .couldNotStartAuth:
            return "Couldn't open the Strava sign-in page."
        case .noResponse:
            return "No response from Strava — check your internet connection."
        case .httpFailure(let status, let body):
            return "Strava request failed (HTTP \(status)). \(body)"
        case .duplicateActivity:
            return "This activity is already on Strava."
        case .refreshFailed:
            return "Could not refresh your Strava session. Reconnect in Settings."
        }
    }
}

// MARK: - HTTP client

enum StravaAPIClient: Sendable {

    /// `application/x-www-form-urlencoded`-correct encoding. Internal so
    /// `_StravaFormEncoderTests` can exercise it via `StravaService.formEncode`.
    internal nonisolated static func formEncode(_ body: [String: String]) -> Data? {
        let allowed = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~ "
        )
        let encoded = body
            .map { key, value -> String in
                let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
                let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
                return "\(k)=\(v)"
            }
            .joined(separator: "&")
            .replacingOccurrences(of: " ", with: "+")
        return encoded.data(using: .utf8)
    }

    static func postForm<T: Decodable>(url: String, body: [String: String]) async throws -> T {
        guard let endpoint = URL(string: url) else {
            throw StravaError.invalidURL
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw StravaError.noResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? "<no body>"
            throw StravaError.httpFailure(status: http.statusCode, body: bodyText)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    static func authedPostForm<T: Decodable>(url: String,
                                             body: [String: String],
                                             token: String) async throws -> T {
        guard let endpoint = URL(string: url) else { throw StravaError.invalidURL }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = formEncode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw StravaError.noResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? "<no body>"
            throw StravaError.httpFailure(status: http.statusCode, body: bodyText)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    static func fetchActivities(token: String,
                              limit: Int,
                              after: Date?) async throws -> [StravaSummaryActivity] {
        var collected: [StravaSummaryActivity] = []
        let perPage = 100
        var page = 1
        let afterEpoch: Int? = after.map { Int($0.timeIntervalSince1970) }

        while collected.count < limit {
            var components = URLComponents(string: "https://www.strava.com/api/v3/athlete/activities")!
            var items: [URLQueryItem] = [
                URLQueryItem(name: "per_page", value: "\(perPage)"),
                URLQueryItem(name: "page", value: "\(page)"),
            ]
            if let afterEpoch {
                items.append(URLQueryItem(name: "after", value: "\(afterEpoch)"))
            }
            components.queryItems = items
            guard let url = components.url else { throw StravaError.invalidURL }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw StravaError.noResponse }
            guard (200..<300).contains(http.statusCode) else {
                let bodyText = String(data: data, encoding: .utf8) ?? "<no body>"
                throw StravaError.httpFailure(status: http.statusCode, body: bodyText)
            }

            let pageBatch = try JSONDecoder().decode([StravaSummaryActivity].self, from: data)
            if pageBatch.isEmpty { break }
            collected.append(contentsOf: pageBatch)

            if pageBatch.count < perPage { break }
            page += 1
        }

        // Strava's ordering for `after` queries isn't guaranteed newest-first,
        // so sort explicitly before capping — keep the most recent `limit`.
        // start_date is ISO-8601 UTC, which sorts chronologically as a string.
        let newestFirst = collected.sorted { $0.start_date > $1.start_date }
        return Array(newestFirst.prefix(limit))
    }
}
