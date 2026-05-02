import SwiftUI

@main
struct MetriclyWatchApp: App {

    @StateObject private var sessionManager     = WatchWorkoutSessionManager()
    @StateObject private var connectivityManager = WatchConnectivityManager.shared

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(sessionManager)
                .environmentObject(connectivityManager)
        }
    }
}
