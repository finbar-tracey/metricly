import SwiftUI

struct WatchRootView: View {
    @EnvironmentObject private var sessionManager: WatchWorkoutSessionManager
    @EnvironmentObject private var connectivity:   WatchConnectivityManager

    var body: some View {
        NavigationStack {
            if sessionManager.isRunning {
                // A session is active — go straight to the right live view
                switch sessionManager.activityType {
                case .traditionalStrengthTraining, .functionalStrengthTraining, .crossTraining:
                    // Gym workout is managed from WatchGymView; live HR is embedded there
                    WatchHeartRateOverlayView()
                default:
                    WatchCardioActiveView()
                }
            } else {
                TabView {
                    WatchGymView()
                        .tabItem { Label("Gym", systemImage: "dumbbell.fill") }

                    WatchCardioStartView()
                        .tabItem { Label("Cardio", systemImage: "figure.run") }
                }
            }
        }
    }
}

// MARK: - Small HR overlay shown when a gym session is active but user
//         navigates away; WatchGymView is the primary gym UI.

private struct WatchHeartRateOverlayView: View {
    @EnvironmentObject private var manager: WatchWorkoutSessionManager

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "heart.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(hrColor)
            Text(manager.heartRate > 0 ? "\(Int(manager.heartRate))" : "--")
                .font(.system(size: 52, weight: .black, design: .rounded))
                .monospacedDigit()
            Text("BPM · \(formatDuration(manager.elapsedSeconds))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Active")
    }

    private var hrColor: Color {
        switch manager.heartRateZone {
        case .resting:  return .gray
        case .fat:      return .blue
        case .cardio:   return .green
        case .peak:     return .orange
        case .max:      return .red
        }
    }
}
