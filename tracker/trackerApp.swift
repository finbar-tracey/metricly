//
//  trackerApp.swift
//  tracker
//
//  Created by Finbar Tracey on 04/03/2026.
//

import SwiftUI
import SwiftData
import os
import AppIntents
import UserNotifications

@main
struct trackerApp: App {
    /// Non-nil on the happy path: SwiftData container ready, app boots
    /// into ContentView. Nil only when both the CloudKit AND local
    /// container creation paths failed AND the on-disk quarantine
    /// recovery also failed — in that case `recoveryError` carries the
    /// last error and `body` shows a recovery screen instead of
    /// fatalError-crashing. The user keeps a launchable app, and any
    /// quarantined `.corrupt-…` files in Application Support are
    /// reachable via Files / iCloud for manual export.
    let modelContainer: ModelContainer?
    let recoveryError: Error?
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        MetriclyShortcutsProvider.updateAppShortcutParameters()

        // Register notification category so action buttons work on every cold launch
        ReminderManager.registerCategory()

        // To enable iCloud sync:
        //   1. In Xcode → Signing & Capabilities → + Capability → iCloud → tick "CloudKit"
        //   2. Create a container named "iCloud.com.yourname.tracker" (or use the default)
        //   3. Uncomment the CloudKit config below and comment out the plain ModelContainer line.
        //
        // Schema lives in MetriclySchema so every container builder in
        // the project — main app + App Intents — uses the same model
        // list. Adding a new @Model? Update MetriclySchema.allModels.

        // Always pass `MetriclyMigrationPlan` so SwiftData walks the
        // V1 → V2 → V3 stages on first launch after an upgrade. Without
        // this, a user upgrading from a pre-V3 store either crashes or
        // gets a default-inferred migration that doesn't match the plan
        // (App Intents were already correctly threading the plan via
        // `MetriclySchema.makeSharedContainer()`; the main app was not).
        // Recovery policy (product rule: quarantine, never delete):
        //   1. Never quarantine on a transient failure (device locked /
        //      protected data unavailable, disk full, file busy…). Those
        //      show the recovery screen and a relaunch simply retries.
        //   2. A failure that looks like genuine corruption or a failed
        //      migration shows the recovery screen first ("Try Again"
        //      relaunches). Only if the NEXT launch fails the same way do
        //      we quarantine the store files and start fresh.
        let outcome = Self.openContainer()
        let container: ModelContainer? = outcome.container
        let recoveryError: Error? = outcome.error
        // Seed UserSettings once so views never need to insert from
        // computed properties. Only runs on the happy path; the
        // recovery scene doesn't need or have a context.
        if let container {
            let context = container.mainContext
            let descriptor = FetchDescriptor<UserSettings>()
            if (try? context.fetchCount(descriptor)) == 0 {
                context.insert(UserSettings())
            }
            if let settings = try? context.fetch(descriptor).first {
                AppearanceMode.migrateLegacyAppStorage(into: settings)
            }

            // Boot Watch connectivity — must happen after the container
            // is ready.
            let phoneManager = AppServices.shared.phoneConnectivity
            phoneManager.modelContext = context
        }
        self.modelContainer = container
        self.recoveryError = recoveryError
    }

    private static let pendingCorruptionKey = "store.pendingCorruptionRetry"

    private static func makeLocalContainer() throws -> ModelContainer {
        try ModelContainer(for: MetriclySchema.schema, migrationPlan: MetriclyMigrationPlan.self)
    }

    private static func openContainer() -> (container: ModelContainer?, error: Error?) {
        let defaults = UserDefaults.standard
        do {
            let cloudConfig = ModelConfiguration(cloudKitDatabase: .automatic)
            let c = try ModelContainer(
                for: MetriclySchema.schema,
                migrationPlan: MetriclyMigrationPlan.self,
                configurations: cloudConfig
            )
            defaults.removeObject(forKey: pendingCorruptionKey)
            MetriclySchema.register(c)
            return (c, nil)
        } catch {
            MetriclySchema.log.error("CloudKit container failed: \(String(describing: error), privacy: .public). Trying local store.")
        }
        do {
            let c = try makeLocalContainer()
            defaults.removeObject(forKey: pendingCorruptionKey)
            MetriclySchema.register(c)
            return (c, nil)
        } catch {
            MetriclySchema.log.error("Local container failed: \(String(describing: error), privacy: .public)")
            // Transient conditions: never touch the files.
            guard UIApplication.shared.isProtectedDataAvailable else {
                MetriclySchema.log.error("Protected data unavailable; not quarantining.")
                return (nil, error)
            }
            guard StoreFailureClassifier.isLikelyCorruption(error) else {
                MetriclySchema.log.error("Failure does not look like corruption; not quarantining.")
                return (nil, error)
            }
            // Genuine corruption: first time, show recovery + Retry.
            guard defaults.bool(forKey: pendingCorruptionKey) else {
                defaults.set(true, forKey: pendingCorruptionKey)
                return (nil, error)
            }
            // Second consecutive corruption failure: quarantine and retry.
            quarantineCorruptedStore()
            do {
                let c = try makeLocalContainer()
                defaults.removeObject(forKey: pendingCorruptionKey)
                MetriclySchema.register(c)
                return (c, nil)
            } catch let retryError {
                MetriclySchema.log.error("Cannot create container after quarantine: \(String(describing: retryError), privacy: .public)")
                return (nil, retryError)
            }
        }
    }

    /// Rename the broken SQLite store files (and their WAL/SHM siblings)
    /// to a timestamped `.corrupt-YYYY-MM-DD-HHmm` suffix so users keep a
    /// recoverable artefact. Apple Support / our own export tooling can
    /// later pull data from these files; deleting them was unrecoverable.
    private static func quarantineCorruptedStore() {
        let fm = FileManager.default
        let stamp: String = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd-HHmm"
            return f.string(from: .now)
        }()

        let groupURL = fm.containerURL(forSecurityApplicationGroupIdentifier: WidgetDataWriter.suiteName)?
            .appending(path: "Library/Application Support")
        let appSupportURL = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let storeNames = ["default.store", "default.store-shm", "default.store-wal"]

        for dir in [groupURL, appSupportURL].compactMap({ $0 }) {
            for name in storeNames {
                let source = dir.appending(path: name)
                guard fm.fileExists(atPath: source.path) else { continue }
                let dest = dir.appending(path: "\(name).corrupt-\(stamp)")
                do {
                    try fm.moveItem(at: source, to: dest)
                    print("📦 Quarantined \(name) → \(dest.lastPathComponent)")
                } catch {
                    // Quarantine failed. Previously this path deleted the
                    // file as a fallback so the app could launch — but
                    // that's data loss the user can never recover from.
                    // Now: leave the file in place. The next container
                    // open will fail again, the app falls through to the
                    // recovery scene, and the user can export the
                    // original file via Files for support.
                    print("⚠️ Quarantine rename failed for \(name): \(error). Leaving file in place; recovery scene will show.")
                }
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            if let modelContainer {
                ContentView()
                    .onAppear { pushWatchContext() }
                    .modelContainer(modelContainer)
            } else {
                DataRecoveryView(error: recoveryError)
            }
        }
    }

    @MainActor
    private func pushWatchContext() {
        guard let modelContainer else { return }
        AppLifecycleCoordinator.refreshWatchAndLiveActivity(modelContainer: modelContainer)
    }
}

// MARK: - AppDelegate: notification delegate (shows banners while app is foregrounded)

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Show notification banners even when the app is in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 willPresent notification: UNNotification,
                                 withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    /// Handle notification taps — deep link into the app
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 didReceive response: UNNotificationResponse,
                                 withCompletionHandler completionHandler: @escaping () -> Void) {
        let action = response.actionIdentifier
        let category = response.notification.request.content.categoryIdentifier

        // Workout reminder: "Start Workout" button or banner tap → open Training tab
        if category == "workoutReminder" || action == "startWorkout" {
            AppRouter.shared.openTrainingTab()
        }

        completionHandler()
    }
}
