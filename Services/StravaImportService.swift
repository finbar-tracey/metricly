import Foundation
import SwiftData

/// Pulls activities from Strava back into Metricly as `CardioSession`
/// rows — the inverse of the existing push path.
///
/// Three responsibilities:
/// 1. Fetch (delegated to `StravaService.fetchActivities`).
/// 2. Map Strava's `sport_type` + `trainer` flag to our `CardioType`,
///    skipping anything we don't model (Swim, Hike, etc.).
/// 3. Dedup against existing rows by `stravaActivityID`. Re-running the
///    sync is safe — it never produces duplicates.
@MainActor
enum StravaImportService {

    struct Result: Equatable {
        var imported: Int = 0
        var skippedExisting: Int = 0
        /// Activities Strava sent that Metricly doesn't currently model
        /// (Swim, Hike, Kayak, etc.). Counted so the UI can be honest
        /// about partial syncs.
        var unsupportedType: Int = 0
    }

    /// Run a full backfill. Caller supplies the existing CardioSessions
    /// so this service doesn't need its own ModelContext fetch.
    static func sync(
        existing: [CardioSession],
        in context: ModelContext,
        limit: Int = 200,
        after: Date? = nil
    ) async throws -> Result {
        let activities = try await StravaService.shared.fetchActivities(limit: limit, after: after)
        return importActivities(activities, existing: existing, in: context)
    }

    /// Pure-value import step — exposed for unit tests that don't want
    /// to round-trip the network. Inserts each new mapped session into
    /// `context` and saves once at the end.
    @discardableResult
    static func importActivities(
        _ activities: [StravaSummaryActivity],
        existing: [CardioSession],
        in context: ModelContext
    ) -> Result {
        let existingIDs = Set(existing.compactMap(\.stravaActivityID))
        var result = Result()

        for activity in activities {
            if existingIDs.contains(activity.id) {
                result.skippedExisting += 1
                continue
            }
            guard let type = mapSportType(activity.sport_type, trainer: activity.trainer) else {
                result.unsupportedType += 1
                continue
            }

            let session = makeSession(from: activity, type: type)
            context.insert(session)
            result.imported += 1
        }

        if result.imported > 0 {
            try? context.save()
        }
        return result
    }

    // MARK: - Mapping (pure value, unit-testable)

    /// Map Strava's `sport_type` (and the trainer flag) to our enum.
    /// Returns nil for activity types Metricly doesn't currently track.
    static func mapSportType(_ raw: String, trainer: Bool?) -> CardioType? {
        let isTrainer = trainer == true
        switch raw {
        case "Run", "TrailRun", "VirtualRun":
            return isTrainer ? .indoorRun : .outdoorRun
        case "Walk":
            return isTrainer ? .indoorWalk : .outdoorWalk
        case "Ride", "MountainBikeRide", "GravelRide", "EBikeRide", "EMountainBikeRide", "VirtualRide":
            // We currently only model outdoor cycle. The trainer flag
            // doesn't get its own bucket (indoor cycling = .outdoorCycle
            // for now; a future schema bump could add an indoor variant).
            return .outdoorCycle
        default:
            return nil
        }
    }

    /// Build a CardioSession from a Strava SummaryActivity. Pure — no
    /// model-context side effects.
    static func makeSession(
        from activity: StravaSummaryActivity,
        type: CardioType
    ) -> CardioSession {
        let session = CardioSession(
            date: parseISO8601(activity.start_date) ?? .now,
            title: activity.name,
            type: type,
            durationSeconds: activity.elapsed_time,
            distanceMeters: activity.distance,
            elevationGainMeters: activity.total_elevation_gain ?? 0
        )
        session.caloriesBurned = activity.calories
        session.avgHeartRate   = activity.average_heartrate
        session.maxHeartRate   = activity.max_heartrate
        session.stravaActivityID = activity.id
        return session
    }

    private static func parseISO8601(_ string: String) -> Date? {
        // Strava sends start_date in UTC; start_date_local has the
        // user's tz offset. Using the UTC field keeps storage canonical.
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}
