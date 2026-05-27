import Foundation
import AuthenticationServices
import Combine
import Security
import UIKit

/// Strava OAuth client + API surface for Metricly.
///
/// Owns the auth lifecycle (connect, disconnect, automatic access-token
/// refresh) and provides typed API calls for the activity push that
/// follow-up commits add.
///
/// ### Credentials
/// The client_secret below is embedded in the app binary. Strava's mobile-
/// app flow accepts this as a known trade-off — the secret is extractable
/// from any shipped binary. If you ever need to rotate it: go to
/// strava.com/settings/api, click "Reset Client Secret", paste the new
/// value into `clientSecret` below. All existing user tokens become
/// invalid because the auth server only honours pairs.
///
/// ### Architecture notes
/// - Auth happens through `ASWebAuthenticationSession` so Apple owns the
///   browser surface, cookies live in a sandboxed jar, and there's no
///   Info.plist URL-scheme registration to maintain.
/// - Tokens persist in Keychain via `StravaTokenStore` (never in
///   UserDefaults — they're bearer credentials).
/// - `accessToken()` is the single entry point for authorized requests;
///   it refreshes proactively when the cached token is within 5 minutes
///   of expiry.
@MainActor
final class StravaService: NSObject, ObservableObject {

    static let shared = StravaService()

    // MARK: - Configuration

    /// Strava-issued API credentials read from `Info.plist`, which gets
    /// them via build-setting substitution from `Config/Secrets.xcconfig`
    /// (gitignored). See `Config/Secrets.xcconfig.example` for setup.
    ///
    /// `nil` means the xcconfig wasn't wired into the project — the value
    /// in Info.plist is the literal `$(STRAVA_CLIENT_ID)` placeholder.
    /// `connect()` checks this and surfaces a usable error instead of
    /// attempting an OAuth flow that would fail in confusing ways.
    private static var clientID: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "STRAVA_CLIENT_ID") as? String,
              !raw.isEmpty,
              !raw.contains("$(") else { return nil }
        return raw
    }

    private static var clientSecret: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "STRAVA_CLIENT_SECRET") as? String,
              !raw.isEmpty,
              !raw.contains("$(") else { return nil }
        return raw
    }

    /// Custom-scheme redirect URI. The scheme matches `callbackScheme`
    /// below; `ASWebAuthenticationSession` intercepts any URL with this
    /// scheme and surfaces it to the completion handler.
    ///
    /// The host must match the Authorization Callback Domain registered
    /// at strava.com/settings/api (we registered `localhost`). Strava
    /// parses redirect_uri as scheme://host/path and rejects requests
    /// whose host doesn't match the registered domain — hence `localhost`
    /// in the host slot with `strava-callback` as the path.
    private static let redirectURI     = "metricly://localhost/strava-callback"
    private static let callbackScheme  = "metricly"

    /// OAuth scopes:
    /// - `read` so we can fetch the athlete profile (name display in Settings).
    /// - `activity:write` so we can push completed sessions.
    /// - `activity:read_all` so we can pull the user's own activities back
    ///   into Metricly (Strava → CardioSession backfill). Users with
    ///   existing tokens issued before this scope was added will need to
    ///   reconnect once for the read scope to take effect.
    private static let scopes = "read,activity:write,activity:read_all"

    // MARK: - Published state

    @Published private(set) var tokens: StravaTokenStore.Tokens?
    @Published private(set) var isAuthorizing: Bool = false
    @Published var lastError: String?

    var isConnected: Bool { tokens != nil }

    /// "First Last" if we have it from the connect-time athlete payload.
    /// Refresh responses don't include the athlete object so we cache
    /// what we saw at connect time.
    var athleteDisplayName: String? {
        guard let t = tokens else { return nil }
        let parts = [t.athleteFirstName, t.athleteLastName]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    // MARK: - Init

    override private init() {
        super.init()
        tokens = StravaTokenStore.load()
    }

    // MARK: - Connect / Disconnect

    /// Begins the OAuth flow. Presents Strava's authorization page via
    /// `ASWebAuthenticationSession`, exchanges the returned code for
    /// tokens, persists them. Cancellation by the user is silent.
    func connect() async {
        guard !isAuthorizing else { return }
        guard let clientID = Self.clientID, Self.clientSecret != nil else {
            lastError = StravaError.notConfigured.errorDescription
            return
        }
        isAuthorizing = true
        defer { isAuthorizing = false }
        lastError = nil

        do {
            let code = try await runAuthSession(clientID: clientID)
            let issued = try await exchangeCodeForTokens(code: code)
            StravaTokenStore.save(issued)
            tokens = issued
        } catch {
            // User-initiated cancel shouldn't read as an error.
            if let asError = error as? ASWebAuthenticationSessionError,
               asError.code == .canceledLogin {
                return
            }
            lastError = (error as? StravaError)?.errorDescription
                     ?? error.localizedDescription
        }
    }

    /// Revokes the access token at Strava and clears local credentials.
    /// Best-effort revoke — if the network call fails we still clear
    /// locally because the user expressed intent to disconnect.
    func disconnect() async {
        if let access = tokens?.accessToken {
            _ = try? await revoke(accessToken: access)
        }
        StravaTokenStore.clear()
        tokens = nil
        lastError = nil
    }

    // MARK: - Token vending

    /// Returns a valid access token, refreshing it from Strava if it's
    /// within 5 minutes of expiry. Throws `.notConnected` if there's no
    /// stored refresh token (user never connected, or disconnected since).
    ///
    /// All authorized API calls should funnel through this rather than
    /// reading `tokens?.accessToken` directly.
    func accessToken() async throws -> String {
        guard var current = tokens else {
            throw StravaError.notConnected
        }
        let buffer: TimeInterval = 5 * 60
        if Date.now.timeIntervalSince1970 + buffer >= current.expiresAt {
            current = try await refresh(refreshToken: current.refreshToken)
            StravaTokenStore.save(current)
            tokens = current
        }
        return current.accessToken
    }

    // MARK: - Private: OAuth session

    private func runAuthSession(clientID: String) async throws -> String {
        // Random opaque value Strava echoes back unchanged in the redirect.
        // Verifying it on the callback rules out a class of CSRF attacks
        // where a malicious app registered for the same URL scheme feeds
        // us a forged authorization code from a different OAuth session.
        let expectedState = Self.makeRandomState()

        var components = URLComponents(string: "https://www.strava.com/oauth/mobile/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id",       value: clientID),
            URLQueryItem(name: "response_type",   value: "code"),
            URLQueryItem(name: "redirect_uri",    value: Self.redirectURI),
            URLQueryItem(name: "approval_prompt", value: "auto"),
            URLQueryItem(name: "scope",           value: Self.scopes),
            URLQueryItem(name: "state",           value: expectedState)
        ]
        guard let authURL = components.url else {
            throw StravaError.invalidURL
        }

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: Self.callbackScheme
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let callbackURL else {
                    continuation.resume(throwing: StravaError.invalidCallback)
                    return
                }
                let comps = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
                let items = comps?.queryItems ?? []

                // Verify state echo before honouring the code. A mismatch
                // means either Strava failed to echo it (a server-side bug
                // we shouldn't paper over) or a third party intercepted
                // the redirect with a forged URL.
                let returnedState = items.first(where: { $0.name == "state" })?.value
                guard returnedState == expectedState else {
                    continuation.resume(throwing: StravaError.stateMismatch)
                    return
                }

                if let code = items.first(where: { $0.name == "code" })?.value {
                    continuation.resume(returning: code)
                } else if let reason = items.first(where: { $0.name == "error" })?.value {
                    continuation.resume(throwing: StravaError.authorizationDenied(reason))
                } else {
                    continuation.resume(throwing: StravaError.invalidCallback)
                }
            }
            session.presentationContextProvider = self
            // Ephemeral session means cookies + storage from the OAuth
            // web view are discarded when the sheet closes. Without this,
            // a previous Strava login on the device carries over and the
            // user may end up authorizing the wrong account.
            session.prefersEphemeralWebBrowserSession = true
            if !session.start() {
                continuation.resume(throwing: StravaError.couldNotStartAuth)
            }
        }
    }

    /// 32 bytes of URL-safe randomness, base64-encoded. Long enough that
    /// brute-forcing a matching state value is infeasible during the
    /// seconds-long window the OAuth sheet is open.
    private static func makeRandomState() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Private: token endpoints

    private struct TokenResponse: Decodable {
        let access_token: String
        let refresh_token: String
        let expires_at: TimeInterval
        let athlete: Athlete?

        struct Athlete: Decodable {
            let id: Int
            let firstname: String?
            let lastname: String?
        }
    }

    private func exchangeCodeForTokens(code: String) async throws -> StravaTokenStore.Tokens {
        guard let clientID = Self.clientID, let clientSecret = Self.clientSecret else {
            throw StravaError.notConfigured
        }
        let response: TokenResponse = try await postForm(
            url: "https://www.strava.com/api/v3/oauth/token",
            body: [
                "client_id":     clientID,
                "client_secret": clientSecret,
                "code":          code,
                "grant_type":    "authorization_code"
            ]
        )
        return StravaTokenStore.Tokens(
            accessToken:       response.access_token,
            refreshToken:      response.refresh_token,
            expiresAt:         response.expires_at,
            athleteID:         response.athlete?.id,
            athleteFirstName:  response.athlete?.firstname,
            athleteLastName:   response.athlete?.lastname
        )
    }

    private func refresh(refreshToken: String) async throws -> StravaTokenStore.Tokens {
        guard let clientID = Self.clientID, let clientSecret = Self.clientSecret else {
            throw StravaError.notConfigured
        }
        let response: TokenResponse = try await postForm(
            url: "https://www.strava.com/api/v3/oauth/token",
            body: [
                "client_id":     clientID,
                "client_secret": clientSecret,
                "refresh_token": refreshToken,
                "grant_type":    "refresh_token"
            ]
        )
        // Refresh response omits the athlete object — preserve cached name.
        return StravaTokenStore.Tokens(
            accessToken:       response.access_token,
            refreshToken:      response.refresh_token,
            expiresAt:         response.expires_at,
            athleteID:         tokens?.athleteID,
            athleteFirstName:  tokens?.athleteFirstName,
            athleteLastName:   tokens?.athleteLastName
        )
    }

    private func revoke(accessToken: String) async throws {
        var request = URLRequest(url: URL(string: "https://www.strava.com/oauth/deauthorize")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        _ = try await URLSession.shared.data(for: request)
    }

    // MARK: - Private: HTTP

    /// POSTs `application/x-www-form-urlencoded` body, decodes JSON
    /// response. Throws `StravaError.httpFailure` on non-2xx with the raw
    /// body so we can debug malformed requests in the wild.
    private func postForm<T: Decodable>(url: String, body: [String: String]) async throws -> T {
        guard let endpoint = URL(string: url) else {
            throw StravaError.invalidURL
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let encoded = body
            .map { key, value in
                let v = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                return "\(key)=\(v)"
            }
            .joined(separator: "&")
        request.httpBody = encoded.data(using: .utf8)

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
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension StravaService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // The system calls this on the main thread already. We assume
        // isolation rather than hop to satisfy the @MainActor isolation
        // on UIApplication access in newer SDKs.
        MainActor.assumeIsolated {
            for scene in UIApplication.shared.connectedScenes {
                if let win = (scene as? UIWindowScene)?.windows.first(where: \.isKeyWindow) {
                    return win
                }
            }
            return UIWindow()
        }
    }
}

// MARK: - Errors

enum StravaError: LocalizedError {
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
        }
    }
}

// MARK: - Upload state (for callers' UI feedback)

/// State machine for a single activity upload attempt. Owned by the
/// caller (a view, typically) so multiple upload sites can each track
/// their own attempt independently rather than coordinating through a
/// shared service-level state.
enum StravaUploadState: Equatable {
    case idle
    case uploading
    case success
    case duplicate                  // Strava said this activity already exists
    case failed(String)             // user-facing error message

    var isInFlight: Bool {
        if case .uploading = self { return true }
        return false
    }
}

// MARK: - Activity upload

/// Minimal Strava activity response payload. Strava returns far more
/// fields than this; we only decode what the app uses (the ID, mostly,
/// so we could later store it on the CardioSession for duplicate-push
/// detection — a follow-up commit).
struct StravaActivity: Decodable {
    let id: Int
    let name: String
    let sport_type: String
    let elapsed_time: Int
    let distance: Double
}

extension StravaService {

    /// Pushes a completed cardio session to Strava as a new activity.
    /// Throws `.duplicateActivity` on HTTP 409 so the caller can mark
    /// the session as "already shared" without surfacing a generic error.
    ///
    /// The Strava docs accept this endpoint with form-encoded params.
    /// We don't upload a route file — that's a separate `/uploads`
    /// endpoint and a much bigger feature (GPX/FIT generation).
    /// Activity name, sport type, elapsed time, distance, and notes are
    /// enough to make the activity visible on the user's Strava feed.
    @discardableResult
    func uploadActivity(_ session: CardioSession) async throws -> StravaActivity {
        let token = try await accessToken()
        let mapping = Self.stravaMapping(for: session)

        // Strava requires a non-empty name. Sessions often have a title
        // like "5k easy", but if blank we fall back to the sport label
        // ("Run", "Walk", "Ride") so Strava doesn't reject the request.
        let name: String = {
            let trimmed = session.title.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? mapping.sportType : trimmed
        }()

        var body: [String: String] = [
            "name":             name,
            "sport_type":       mapping.sportType,
            "start_date_local": Self.iso8601LocalString(from: session.date),
            "elapsed_time":     String(Int(session.durationSeconds))
        ]
        if session.distanceMeters > 0.5 {
            body["distance"] = String(format: "%.1f", session.distanceMeters)
        }
        let notes = session.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !notes.isEmpty {
            body["description"] = notes
        }
        if mapping.isTrainer {
            body["trainer"] = "1"
        }

        do {
            return try await authedPostForm(
                url: "https://www.strava.com/api/v3/activities",
                body: body,
                token: token
            )
        } catch StravaError.httpFailure(let status, _) where status == 409 {
            // 409 = duplicate. Strava returns this when an identical
            // session was uploaded recently. Surface explicitly so the
            // UI can show "Already on Strava" instead of a generic error.
            throw StravaError.duplicateActivity
        }
    }

    // MARK: - Mapping

    private struct StravaMapping {
        let sportType: String   // Strava sport_type value
        let isTrainer: Bool     // true for indoor/trainer sessions
    }

    private static func stravaMapping(for session: CardioSession) -> StravaMapping {
        let type = CardioType(rawValue: session.cardioType) ?? .outdoorRun
        switch type {
        case .outdoorRun:   return .init(sportType: "Run",  isTrainer: false)
        case .indoorRun:    return .init(sportType: "Run",  isTrainer: true)
        case .outdoorWalk:  return .init(sportType: "Walk", isTrainer: false)
        case .indoorWalk:   return .init(sportType: "Walk", isTrainer: true)
        case .outdoorCycle: return .init(sportType: "Ride", isTrainer: false)
        }
    }

    // MARK: - Date

    /// Strava's `start_date_local` accepts standard ISO 8601 with the
    /// activity's local timezone offset. Default ISO 8601 formatter output
    /// (e.g. "2026-05-11T13:45:00+0100") is what we want.
    private static func iso8601LocalString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    // MARK: - Authorized POST

    /// `postForm` with a Bearer Authorization header. Kept separate from
    /// the unauthenticated `postForm` so the OAuth endpoints (which don't
    /// take a Bearer token) don't accidentally pick up an Authorization
    /// header that would confuse Strava's token grant flow.
    private func authedPostForm<T: Decodable>(url: String,
                                              body: [String: String],
                                              token: String) async throws -> T {
        guard let endpoint = URL(string: url) else { throw StravaError.invalidURL }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let encoded = body
            .map { key, value in
                let v = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                return "\(key)=\(v)"
            }
            .joined(separator: "&")
        request.httpBody = encoded.data(using: .utf8)

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
}


// MARK: - Activity backfill (Strava → app)

/// Lean projection of Strava's SummaryActivity — only the fields the
/// import service needs. JSON decoding ignores any extra keys Strava
/// sends, so adding a field here doesn't risk breaking on a Strava-
/// side schema bump.
struct StravaSummaryActivity: Decodable {
    let id: Int
    let name: String
    let sport_type: String
    let start_date: String          // ISO 8601 with timezone
    let elapsed_time: Double        // seconds
    let distance: Double            // meters
    let total_elevation_gain: Double?
    let average_heartrate: Double?
    let max_heartrate: Double?
    let calories: Double?
    let trainer: Bool?              // true → indoor variant
}

extension StravaService {

    /// Fetch the most recent `limit` activities, walking pages until we
    /// either hit the limit or Strava returns an empty page. Authorized
    /// — caller must have completed OAuth with the `activity:read_all`
    /// scope.
    ///
    /// `after` truncates by start time: only activities with
    /// `start_date >= after` are returned. Pass `nil` for "no floor".
    func fetchActivities(limit: Int = 200, after: Date? = nil) async throws -> [StravaSummaryActivity] {
        let token = try await accessToken()

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

            // Strava returns at most `perPage` per request — anything
            // smaller means the next page would be empty.
            if pageBatch.count < perPage { break }
            page += 1
        }

        return Array(collected.prefix(limit))
    }
}
