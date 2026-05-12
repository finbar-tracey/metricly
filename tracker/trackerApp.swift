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
    let modelContainer: ModelContainer
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

        let container: ModelContainer
        do {
            let cloudConfig = ModelConfiguration(cloudKitDatabase: .automatic)
            container = try ModelContainer(for: MetriclySchema.schema, configurations: cloudConfig)
        } catch {
            print("⚠️ CloudKit container failed: \(error). Trying local store.")
            do {
                container = try ModelContainer(for: MetriclySchema.schema)
            } catch {
                // Local store can't open. Previously this path silently
                // deleted default.store / -shm / -wal — catastrophic for
                // a fitness app where users have years of training data.
                // Instead: quarantine the broken files (rename with a
                // timestamp) so the data is recoverable manually, then
                // start fresh on top.
                print("⚠️ Local store corrupted, quarantining: \(error)")
                Self.quarantineCorruptedStore()
                do {
                    container = try ModelContainer(for: MetriclySchema.schema)
                } catch {
                    fatalError("Cannot create any SwiftData container: \(error)")
                }
            }
        }
        // Seed UserSettings once so views never need to insert from computed properties
        let context = container.mainContext
        let descriptor = FetchDescriptor<UserSettings>()
        if (try? context.fetchCount(descriptor)) == 0 {
            context.insert(UserSettings())
        }
        self.modelContainer = container

        // Boot Watch connectivity — must happen after the container is ready
        let phoneManager = PhoneConnectivityManager.shared
        phoneManager.modelContext = context
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
                    // If even the rename fails, fall back to delete so we
                    // can still launch the app. Data is gone in that case,
                    // but the alternative is fatalError on every launch.
                    try? fm.removeItem(at: source)
                    print("⚠️ Quarantine rename failed for \(name); deleted instead: \(error)")
                }
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear { pushWatchContext() }
        }
        .modelContainer(modelContainer)
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
        let workouts = (try? modelContainer.mainContext.fetch(FetchDescriptor<Workout>())) ?? []
        let inProgress = workouts.first { !$0.isTemplate && $0.endTime == nil }
        PhoneConnectivityManager.shared.publishActiveWorkout(
            name: inProgress?.name,
            startedAt: inProgress?.date
        )
        PhoneConnectivityManager.shared.pushWatchContext()
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
