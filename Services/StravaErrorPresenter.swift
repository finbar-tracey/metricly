import Foundation

/// Maps a `StravaError` (or any thrown error) to the user-facing message +
/// banner kind that `AppErrorBus` should display.
///
/// Lifted out of `StravaSettingsSection` so the status-code → message
/// mapping is unit-testable without standing up the whole SwiftUI view
/// + bus + import service. The only thing the view does now is forward
/// the result to `AppErrorBus.shared.report(...)`.
///
/// The presenter classifies errors into discrete `Reason` cases first,
/// then attaches a localized string. Tests pin the classification (which
/// is stable, regression-prone, and the actual contract) and assert the
/// message is non-empty without locking the English copy.
enum StravaErrorPresenter {

    /// The user-facing categorisation of a Strava sync failure. New
    /// categories should be added when the underlying API surfaces a
    /// new actionable case (anything that maps to a different banner
    /// recovery suggestion or kind).
    nonisolated enum Reason: Equatable, Sendable {
        /// Token doesn't carry the scope we need (e.g. pre-bump
        /// `activity:read` connection trying to pull activities). The
        /// fix is reconnect; we send the user to that flow.
        case tokenScopeStale
        /// Rate-limit. Strava enforces per-15-min and per-day quotas;
        /// hitting either returns 429 and the only sane recovery is to
        /// wait it out.
        case rateLimited
        /// Caught everything else — network blip, 500, decoding mismatch.
        /// Caller retries; we surface a generic "try again" copy.
        case generic
    }

    struct Presentation {
        let reason: Reason
        let message: String
        let kind: AppErrorBus.BannerError.Kind
    }

    /// Classify an error and pair it with a user-facing message.
    static func present(_ error: Error) -> Presentation {
        if let strava = error as? StravaError {
            switch strava {
            case .httpFailure(let status, _) where status == 401:
                return Presentation(
                    reason: .tokenScopeStale,
                    message: String(
                        localized: "Reconnect Strava to enable sync — your existing connection was created before this feature shipped.",
                        comment: "Shown when Strava returns 401 (token missing the read scope)"
                    ),
                    kind: .warning
                )
            case .httpFailure(let status, _) where status == 429:
                return Presentation(
                    reason: .rateLimited,
                    message: String(
                        localized: "Strava is rate-limiting us — try again in 15 minutes.",
                        comment: "Shown when Strava returns 429 (rate limit)"
                    ),
                    kind: .warning
                )
            default:
                break
            }
        }
        return Presentation(
            reason: .generic,
            message: String(
                localized: "Strava sync failed — check your connection and try again.",
                comment: "Generic Strava sync failure"
            ),
            kind: .failure
        )
    }
}
