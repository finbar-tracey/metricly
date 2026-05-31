import AuthenticationServices
import Foundation
import Security
import UIKit

// MARK: - OAuth configuration

enum StravaAuthConfig {
    static let redirectURI    = "metricly://localhost/strava-callback"
    static let callbackScheme = "metricly"
    static let scopes         = "read,activity:write,activity:read_all"

    static var clientID: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "STRAVA_CLIENT_ID") as? String,
              !raw.isEmpty,
              !raw.contains("$(") else { return nil }
        return raw
    }

    static var clientSecret: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "STRAVA_CLIENT_SECRET") as? String,
              !raw.isEmpty,
              !raw.contains("$(") else { return nil }
        return raw
    }
}

// MARK: - Connect / disconnect / token vending

extension StravaService {

    func connect() async {
        guard !isAuthorizing else { return }
        guard let clientID = StravaAuthConfig.clientID, StravaAuthConfig.clientSecret != nil else {
            lastError = StravaError.notConfigured.errorDescription
            return
        }
        setAuthorizing(true)
        defer { setAuthorizing(false) }
        lastError = nil

        do {
            let code = try await runAuthSession(clientID: clientID)
            let issued = try await exchangeCodeForTokens(code: code)
            StravaTokenStore.save(issued)
            applyTokens(issued)
        } catch {
            if let asError = error as? ASWebAuthenticationSessionError,
               asError.code == .canceledLogin {
                return
            }
            lastError = (error as? StravaError)?.errorDescription
                     ?? error.localizedDescription
        }
    }

    func disconnect() async {
        if let access = tokens?.accessToken {
            _ = try? await revoke(accessToken: access)
        }
        StravaTokenStore.clear()
        applyTokens(nil)
        lastError = nil
    }

    func accessToken() async throws -> String {
        guard var current = tokens else {
            throw StravaError.notConnected
        }
        let buffer: TimeInterval = 5 * 60
        if Date.now.timeIntervalSince1970 + buffer >= current.expiresAt {
            current = try await refresh(refreshToken: current.refreshToken)
            StravaTokenStore.save(current)
            applyTokens(current)
        }
        return current.accessToken
    }

    // MARK: - OAuth session

    private func runAuthSession(clientID: String) async throws -> String {
        let expectedState = Self.makeRandomState()

        var components = URLComponents(string: "https://www.strava.com/oauth/mobile/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id",       value: clientID),
            URLQueryItem(name: "response_type",   value: "code"),
            URLQueryItem(name: "redirect_uri",    value: StravaAuthConfig.redirectURI),
            URLQueryItem(name: "approval_prompt", value: "auto"),
            URLQueryItem(name: "scope",           value: StravaAuthConfig.scopes),
            URLQueryItem(name: "state",           value: expectedState)
        ]
        guard let authURL = components.url else {
            throw StravaError.invalidURL
        }

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: StravaAuthConfig.callbackScheme
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
            session.prefersEphemeralWebBrowserSession = true
            if !session.start() {
                continuation.resume(throwing: StravaError.couldNotStartAuth)
            }
        }
    }

    private static func makeRandomState() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Token endpoints

    private struct TokenResponse: Decodable, Sendable {
        let access_token: String
        let refresh_token: String
        let expires_at: TimeInterval
        let athlete: Athlete?

        struct Athlete: Decodable, Sendable {
            let id: Int
            let firstname: String?
            let lastname: String?
        }
    }

    private func exchangeCodeForTokens(code: String) async throws -> StravaTokenStore.Tokens {
        guard let clientID = StravaAuthConfig.clientID,
              let clientSecret = StravaAuthConfig.clientSecret else {
            throw StravaError.notConfigured
        }
        let response: TokenResponse = try await StravaAPIClient.postForm(
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
        guard let clientID = StravaAuthConfig.clientID,
              let clientSecret = StravaAuthConfig.clientSecret else {
            throw StravaError.notConfigured
        }
        let refresher = StravaTokenRefresher(
            clientID: clientID,
            clientSecret: clientSecret,
            session: .shared,
            preserveAthleteFrom: tokens
        )
        return try await refresher.refresh(refreshToken: refreshToken)
    }

    private func revoke(accessToken: String) async throws {
        var request = URLRequest(url: URL(string: "https://www.strava.com/oauth/deauthorize")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        _ = try await URLSession.shared.data(for: request)
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension StravaService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let win = scenes.lazy.flatMap(\.windows).first(where: \.isKeyWindow) {
            return win
        }
        guard let scene = scenes.first else {
            fatalError("No UIWindowScene available for Strava OAuth presentation")
        }
        return UIWindow(windowScene: scene)
    }
}
