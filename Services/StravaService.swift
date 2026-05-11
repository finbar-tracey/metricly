import Foundation
import AuthenticationServices
import Combine
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

    /// Strava-issued API credentials. Replace if you regenerate them at
    /// strava.com/settings/api.
    private static let clientID     = "243791"
    private static let clientSecret = "14711d5956683b4d0c586a4f43fbd3b34fde5fd9"

    /// Custom-scheme redirect URI. The scheme matches `callbackScheme`
    /// below; `ASWebAuthenticationSession` will intercept any URL with
    /// this scheme and surface it to the completion handler.
    private static let redirectURI     = "metricly://strava-callback"
    private static let callbackScheme  = "metricly"

    /// OAuth scopes:
    /// - `read` so we can fetch the athlete profile (name display in Settings).
    /// - `activity:write` so we can push completed sessions.
    /// We deliberately don't request `activity:read_all` — we don't pull
    /// anything from Strava (HealthKit already delivers those activities).
    private static let scopes = "read,activity:write"

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
        isAuthorizing = true
        defer { isAuthorizing = false }
        lastError = nil

        do {
            let code = try await runAuthSession()
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

    private func runAuthSession() async throws -> String {
        var components = URLComponents(string: "https://www.strava.com/oauth/mobile/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id",       value: Self.clientID),
            URLQueryItem(name: "response_type",   value: "code"),
            URLQueryItem(name: "redirect_uri",    value: Self.redirectURI),
            URLQueryItem(name: "approval_prompt", value: "auto"),
            URLQueryItem(name: "scope",           value: Self.scopes)
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
                if let code = items.first(where: { $0.name == "code" })?.value {
                    continuation.resume(returning: code)
                } else if let reason = items.first(where: { $0.name == "error" })?.value {
                    continuation.resume(throwing: StravaError.authorizationDenied(reason))
                } else {
                    continuation.resume(throwing: StravaError.invalidCallback)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            if !session.start() {
                continuation.resume(throwing: StravaError.couldNotStartAuth)
            }
        }
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
        let response: TokenResponse = try await postForm(
            url: "https://www.strava.com/api/v3/oauth/token",
            body: [
                "client_id":     Self.clientID,
                "client_secret": Self.clientSecret,
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
        let response: TokenResponse = try await postForm(
            url: "https://www.strava.com/api/v3/oauth/token",
            body: [
                "client_id":     Self.clientID,
                "client_secret": Self.clientSecret,
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
    case invalidURL
    case invalidCallback
    case authorizationDenied(String)
    case couldNotStartAuth
    case noResponse
    case httpFailure(status: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "You're not connected to Strava."
        case .invalidURL:
            return "Internal: malformed Strava URL."
        case .invalidCallback:
            return "Strava sent an unexpected response. Try connecting again."
        case .authorizationDenied(let reason):
            return "Strava authorization failed: \(reason)"
        case .couldNotStartAuth:
            return "Couldn't open the Strava sign-in page."
        case .noResponse:
            return "No response from Strava — check your internet connection."
        case .httpFailure(let status, let body):
            return "Strava request failed (HTTP \(status)). \(body)"
        }
    }
}
