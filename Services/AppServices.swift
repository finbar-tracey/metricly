import SwiftUI
import UIKit

/// Root-level service holder for gradual migration off `.shared` singletons.
@MainActor @Observable
final class AppServices {
    static let shared = AppServices()

    let router = AppRouter.shared
    let phoneConnectivity = PhoneConnectivityManager.shared
    let strava = StravaService.shared

    /// Gradual migration off `.shared` in feature views — still backed by singletons.
    var workoutActivity: WorkoutActivityManager { WorkoutActivityManager.shared }
    var healthKit: HealthKitManager { HealthKitManager.shared }
    var healthDataCache: HealthDataCache { HealthDataCache.shared }
    var appErrorBus: AppErrorBus { AppErrorBus.shared }
    var syncStatus: SyncStatusManager { SyncStatusManager.shared }
    var cardioTracker: CardioTracker { CardioTracker.shared }

    func openURL(_ url: URL) async {
        await UIApplication.shared.open(url)
    }

    func openSettings() async {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        await openURL(url)
    }

    private init() {}
}

private struct AppServicesKey: EnvironmentKey {
    static let defaultValue = AppServices.shared
}

extension EnvironmentValues {
    var appServices: AppServices {
        get { self[AppServicesKey.self] }
        set { self[AppServicesKey.self] = newValue }
    }
}
