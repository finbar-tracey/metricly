import Foundation
import Security

/// Keychain wrapper for Strava OAuth tokens.
///
/// Strava access tokens expire every 6 hours; refresh tokens don't expire
/// unless the user explicitly revokes access at strava.com/settings/apps.
/// Both live behind the same Keychain entry so rotating one (re-login) or
/// clearing locally (disconnect) wipes both atomically.
///
/// We avoid `UserDefaults` because these are bearer credentials — anyone
/// with the access token can read and write the user's Strava activities.
enum StravaTokenStore {

    private static let service = "com.metricly.strava.tokens"
    private static let account = "default"

    /// Under XCTest the keychain entitlement is stripped (the test host is built
    /// with `CODE_SIGNING_ALLOWED=NO`), so `SecItem*` calls fail and round-trips
    /// can't be verified. Fall back to an in-memory store there so token logic
    /// stays testable. Never active in a signed production build (XCTest absent).
    private static let isRunningTests: Bool =
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        || NSClassFromString("XCTestCase") != nil
    private static var inMemoryTokens: Tokens?

    struct Tokens: Codable, Equatable, Sendable {
        var accessToken: String
        var refreshToken: String
        /// Unix timestamp (seconds since epoch) when the access token
        /// expires. Compared against `Date.now` with a buffer to decide
        /// whether to refresh before the next API call.
        var expiresAt: TimeInterval
        var athleteID: Int?
        var athleteFirstName: String?
        var athleteLastName: String?

        var isExpired: Bool { Date.now.timeIntervalSince1970 >= expiresAt }
    }

    // MARK: - Public API

    static func load() -> Tokens? {
        if isRunningTests { return inMemoryTokens }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(Tokens.self, from: data)
    }

    /// Upsert the stored tokens. Returns `false` if encoding or the Keychain
    /// write failed so callers can avoid appearing connected without persistence.
    @discardableResult
    static func save(_ tokens: Tokens) -> Bool {
        if isRunningTests { inMemoryTokens = tokens; return true }
        guard let data = try? JSONEncoder().encode(tokens) else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        // Accessible after first unlock so background refresh / upload can run
        // while locked; ThisDeviceOnly keeps bearer tokens out of backups.
        // Setting the accessibility attribute on update migrates items that
        // were stored with the older (backup-eligible) class.
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        switch updateStatus {
        case errSecSuccess:
            return true
        case errSecItemNotFound:
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            if addStatus != errSecSuccess {
                print("StravaTokenStore: SecItemAdd failed (\(addStatus))")
            }
            return addStatus == errSecSuccess
        default:
            print("StravaTokenStore: SecItemUpdate failed (\(updateStatus))")
            return false
        }
    }

    static func clear() {
        if isRunningTests { inMemoryTokens = nil; return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
