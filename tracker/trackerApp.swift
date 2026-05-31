//
//  trackerApp.swift
//  tracker
//
//  Created by Finbar Tracey on 04/03/2026.
//

import SwiftUI
import SwiftData
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
    /// Light / Dark / System appearance preference (Settings → Appearance).
    /// "system" → nil → follows the device.
    @AppStorage("appearance") private var appearance = "system"
    private var preferredScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

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
        let container: ModelContainer?
        let recoveryError: Error?
        do {
            let cloudConfig = ModelConfiguration(cloudKitDatabase: .automatic)
            container = try ModelContainer(
                for: MetriclySchema.schema,
                migrationPlan: MetriclyMigrationPlan.self,
                configurations: cloudConfig
            )
            recoveryError = nil
        } catch {
            print("⚠️ CloudKit container failed: \(error). Trying local store.")
            do {
                container = try ModelContainer(
                    for: MetriclySchema.schema,
                    migrationPlan: MetriclyMigrationPlan.self
                )
                recoveryError = nil
            } catch {
                // Local store can't open. Quarantine the broken files
                // (rename with a timestamp) so the data is reachable via
                // Files for manual export, then retry once on a fresh
                // store. If even that fails, fall through to the
                // recovery scene — DON'T fatalError; the user keeps a
                // launchable app and a recoverable on-disk trail.
                print("⚠️ Local store corrupted, quarantining: \(error)")
                Self.quarantineCorruptedStore()
                do {
                    container = try ModelContainer(
                        for: MetriclySchema.schema,
                        migrationPlan: MetriclyMigrationPlan.self
                    )
                    recoveryError = nil
                } catch let retryError {
                    // Last resort: surface a recovery screen.
                    print("⚠️ Cannot create any SwiftData container after quarantine: \(retryError)")
                    container = nil
                    recoveryError = retryError
                }
            }
        }
        // Seed UserSettings once so views never need to insert from
        // computed properties. Only runs on the happy path; the
        // recovery scene doesn't need or have a context.
        if let container {
            let context = container.mainContext
            let descriptor = FetchDescriptor<UserSettings>()
            if (try? context.fetchCount(descriptor)) == 0 {
                context.insert(UserSettings())
            }

            // Boot Watch connectivity — must happen after the container
            // is ready.
            let phoneManager = PhoneConnectivityManager.shared
            phoneManager.modelContext = context
        }
        self.modelContainer = container
        self.recoveryError = recoveryError
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
                    .preferredColorScheme(preferredScheme)
                    .onAppear { pushWatchContext() }
                    .modelContainer(modelContainer)
            } else {
                DataRecoveryView(error: recoveryError)
            }
        }
    }

    /// Refresh the Watch's view of the world on foreground. Two things
    /// happen, in order:
    /// 1. Walk the workout table to self-heal active-workout state. If
    ///    the user deleted an in-progress workout (or the cached state is
    ///    stale from a kill+relaunch), this brings the shared defaults in
    ///    line with reality before the push.
    /// 2. Build + push the canonical Watch context via the shared
    ///    `PhoneConnectivityManager.pushWatchContext()` — the same code
    ///    path the WCSession reply handler uses, so push and reply can't
    ///    drift apart.
    @MainActor
    private func pushWatchContext() {
        // Recovery scene has no container; nothing to push.
        guard let modelContainer else { return }
        let workouts = (try? modelContainer.mainContext.fetch(FetchDescriptor<Workout>())) ?? []
        let inProgress = workouts.first { !$0.isTemplate && $0.endTime == nil }
        PhoneConnectivityManager.shared.publishActiveWorkout(
            name: inProgress?.name,
            startedAt: inProgress?.date
        )
        PhoneConnectivityManager.shared.pushWatchContext()
        // Reconcile any orphaned Live Activities left over from a previous
        // force-quit. If there's a real in-progress workout, re-attach the
        // manager to its existing activity so updates resume; otherwise
        // end every dangling activity on the lock screen.
        WorkoutActivityManager.shared.reconcileOnLaunch(
            activeWorkoutName: inProgress?.name,
            activeWorkoutStartedAt: inProgress?.date
        )
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
            NotificationCenter.default.post(name: .openTrainingTab, object: nil)
        }

        completionHandler()
    }
}
