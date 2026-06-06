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
        strava: StravaService,
        limit: Int = 200,
        after: Date? = nil
    ) async throws -> Result {
        let activities = try await strava.fetchActivities(limit: limit, after: after)
        return importActivities(activities, existing: existing, in: context)
    }

    /// Tolerances for the fuzzy-dedup check. These are the windows
    /// within which two CardioSession-shaped events are considered
    /// "the same workout from different sources" (e.g. Apple Watch
    /// recorded → both HealthKit and Strava both received it, then
    /// Metricly imports Strava and would otherwise create a duplicate).
    ///
    /// Tunable knobs — not in `EngineConstants` because they belong
    /// strictly to the import path, not the engine's reasoning.
    enum DedupTolerance {
        /// Start time must match within this window. Apple Health and
        /// Strava sometimes disagree by a few seconds on the trigger
        /// instant; 5 minutes is the published tolerance Apple suggests
        /// for matching HKWorkout records and is generous enough for
        /// manual entries with rounded minutes.
        static let startWindow: TimeInterval = 5 * 60
        /// Elapsed time must match within this window. Watch and
        /// Strava can disagree on auto-pause behaviour by ~30s; 60s is
        /// safely above that without merging genuinely different
        /// sessions of comparable length.
        static let durationWindow: TimeInterval = 60
        /// Distance must match within this many meters. GPS jitter
        /// alone can shift the reported total by ±50m; 100m covers
        /// that plus the small differences in distance-smoothing
        /// algorithms across vendors.
        static let distanceWindow: Double = 100
    }

    /// Pure-value import step — exposed for unit tests that don't want
    /// to round-trip the network. Inserts each new mapped session into
    /// `context` and saves once at the end.
    ///
    /// Two-layer dedup:
    ///  1. **By Strava activity ID** — catches any activity Metricly
    ///     previously imported OR pushed up to Strava (we stamp the
    ///     `stravaActivityID` on the session at upload time too).
    ///  2. **Fuzzy match against existing sessions** — same CardioType
    ///     and start/duration/distance within `DedupTolerance`.
    ///     Catches the common watch-recorded path where the session
    ///     lands in both Apple Health (via HKWorkout) and Strava (via
    ///     auto-share), then Metricly imports Strava — without this
    ///     layer the user gets two cardio rows for the same run.
    ///
    /// The seen-ID set is mutated inside the loop so duplicate IDs
    /// within a single Strava response don't slip through either.
    @discardableResult
    static func importActivities(
        _ activities: [StravaSummaryActivity],
        existing: [CardioSession],
        in context: ModelContext
    ) -> Result {
        var seenIDs = Set(existing.compactMap(\.stravaActivityID))
        // Snapshot existing sessions for the fuzzy match. We append to
        // it as we insert so two activities in the same response that
        // look like the same session (rare but possible if Strava
        // surfaces both an "upload" and a "manual log" of the same
        // event) only land once.
        var fuzzyPool: [CardioSession] = existing
        var result = Result()

        for activity in activities {
            // Layer 1: ID match (both directions — already-imported AND
            // already-uploaded sessions live in `seenIDs`).
            if seenIDs.contains(activity.id) {
                result.skippedExisting += 1
                continue
            }
            guard let type = mapSportType(activity.sport_type, trainer: activity.trainer) else {
                result.unsupportedType += 1
                continue
            }

            let session = makeSession(from: activity, type: type)

            // Layer 2: fuzzy match against existing + already-inserted
            // sessions in this batch.
            if fuzzyPool.contains(where: { isFuzzyDuplicate($0, of: session) }) {
                result.skippedExisting += 1
                seenIDs.insert(activity.id)
                continue
            }

            context.insert(session)
            seenIDs.insert(activity.id)
            fuzzyPool.append(session)
            result.imported += 1
        }

        if result.imported > 0 {
            try? context.save()
        }
        return result
    }

    /// Pure predicate — exposed so the test bundle can pin the
    /// tolerance windows without standing up a full ModelContext.
    /// Returns true when `existing` and `candidate` look like the
    /// same real-world event captured by two different ingestion
    /// paths (e.g. HKWorkout + Strava auto-share).
    static func isFuzzyDuplicate(_ existing: CardioSession,
                                 of candidate: CardioSession) -> Bool {
        guard existing.type == candidate.type else { return false }
        let t = DedupTolerance.self
        let startDelta = abs(existing.start.timeIntervalSince(candidate.start))
        guard startDelta <= t.startWindow else { return false }
        let durationDelta = abs(existing.durationSeconds - candidate.durationSeconds)
        guard durationDelta <= t.durationWindow else { return false }
        let distanceDelta = abs(existing.distanceMeters - candidate.distanceMeters)
        guard distanceDelta <= t.distanceWindow else { return false }
        return true
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
