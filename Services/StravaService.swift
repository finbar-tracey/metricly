import Combine
import Foundation

/// Strava OAuth client + API surface for Metricly.
///
/// Implementation is split across `Services/Strava/` (`StravaAuth`,
/// `StravaAPIClient`, `StravaUpload`). This type owns published connection
/// state and is the injection point via `AppServices`.
@MainActor
final class StravaService: NSObject, ObservableObject {

    static let shared = StravaService()

    @Published private(set) var tokens: StravaTokenStore.Tokens?
    @Published private(set) var isAuthorizing: Bool = false
    @Published var lastError: String?

    var isConnected: Bool { tokens != nil }

    var athleteDisplayName: String? {
        guard let t = tokens else { return nil }
        let parts = [t.athleteFirstName, t.athleteLastName]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    override private init() {
        super.init()
        tokens = StravaTokenStore.load()
    }

    func applyTokens(_ value: StravaTokenStore.Tokens?) {
        tokens = value
    }

    func setAuthorizing(_ value: Bool) {
        isAuthorizing = value
    }

    /// Forwards to `StravaAPIClient.formEncode` — kept on the facade so
    /// `StravaFormEncoderTests` can pin encoding without reaching into Strava/.
    internal nonisolated static func formEncode(_ body: [String: String]) -> Data? {
        StravaAPIClient.formEncode(body)
    }
}

// MARK: - Upload state (UI feedback; kept on facade file for target visibility)

enum StravaUploadState: Equatable {
    case idle
    case uploading
    case success
    case duplicate
    case failed(String)

    var isInFlight: Bool {
        if case .uploading = self { return true }
        return false
    }
}

struct StravaActivity: Decodable, Sendable {
    let id: Int
    let name: String
    let sport_type: String
    let elapsed_time: Int
    let distance: Double
}

struct StravaSummaryActivity: Decodable, Sendable {
    let id: Int
    let name: String
    let sport_type: String
    let start_date: String
    let elapsed_time: Double
    let distance: Double
    let total_elevation_gain: Double?
    let average_heartrate: Double?
    let max_heartrate: Double?
    let calories: Double?
    let trainer: Bool?
}

// MARK: - Upload + activity fetch

extension StravaService {

    @discardableResult
    func uploadActivity(_ session: CardioSession) async throws -> StravaActivity {
        let token = try await accessToken()
        let mapping = Self.stravaMapping(for: session)

        let name: String = {
            let trimmed = session.title.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? mapping.sportType : trimmed
        }()

        var body: [String: String] = [
            "name":             name,
            "sport_type":       mapping.sportType,
            "start_date_local": Self.iso8601LocalString(from: session.start),
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
            return try await StravaAPIClient.authedPostForm(
                url: "https://www.strava.com/api/v3/activities",
                body: body,
                token: token
            )
        } catch StravaError.httpFailure(let status, _) where status == 409 {
            throw StravaError.duplicateActivity
        }
    }

    func fetchActivities(limit: Int = 200, after: Date? = nil) async throws -> [StravaSummaryActivity] {
        let token = try await accessToken()
        return try await StravaAPIClient.fetchActivities(token: token, limit: limit, after: after)
    }

    private struct StravaMapping {
        let sportType: String
        let isTrainer: Bool
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

    private static func iso8601LocalString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
}
