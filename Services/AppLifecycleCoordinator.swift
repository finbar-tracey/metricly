import SwiftData
import Foundation

/// Foreground lifecycle hooks shared by the app entry and root shell.
enum AppLifecycleCoordinator {

    /// Refresh Watch context and reconcile Live Activities. Same path for
    /// cold launch (`onAppear`) and returning from background (`scenePhase.active`).
    /// Push Watch context and reconcile Live Activities after data changes.
    @MainActor
    static func refreshExtensions(modelContainer: ModelContainer) {
        refreshWatchAndLiveActivity(modelContainer: modelContainer)
    }

    @MainActor
    static func refreshWatchAndLiveActivity(modelContainer: ModelContainer) {
        let workouts = (try? modelContainer.mainContext.fetch(FetchDescriptor<Workout>())) ?? []
        let inProgress = workouts.first { !$0.isTemplate && $0.endTime == nil }
        PhoneConnectivityManager.shared.publishActiveWorkout(
            name: inProgress?.name,
            startedAt: inProgress?.date
        )
        PhoneConnectivityManager.shared.pushWatchContext()
        WorkoutActivityManager.shared.reconcileOnLaunch(
            activeWorkoutName: inProgress?.name,
            activeWorkoutStartedAt: inProgress?.date
        )
    }
}
