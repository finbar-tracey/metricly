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

    struct Tokens: Codable, Equatable {
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

    /// Atomically upsert the stored tokens. Idempotent.
    static func save(_ tokens: Tokens) {
        guard let data = try? JSONEncoder().encode(tokens) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            // Marking as accessible only after first unlock so background
            // refresh / upload can run while the device is locked but past
            // the post-boot lock screen.
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
