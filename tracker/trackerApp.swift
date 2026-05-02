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
        let allModels: [any PersistentModel.Type] = [
            Workout.self, Exercise.self, ExerciseSet.self, UserSettings.self,
            BodyWeightEntry.self, TrainingProgram.self, ProgramDay.self, ProgramExercise.self,
            BodyMeasurement.self, LiftGoal.self, ProgressPhoto.self, CaffeineEntry.self,
            WaterEntry.self, CreatineEntry.self, ManualActivity.self, CardioSession.self
        ]

        let container: ModelContainer
        do {
            let cloudConfig = ModelConfiguration(cloudKitDatabase: .automatic)
            container = try ModelContainer(for: Schema(allModels), configurations: cloudConfig)
        } catch {
            print("⚠️ CloudKit container failed: \(error). Trying local store.")
            do {
                container = try ModelContainer(for: Schema(allModels))
            } catch {
                // Local store is corrupted — delete it and start fresh
                print("⚠️ Local store corrupted, rebuilding: \(error)")
                let fm = FileManager.default
                // The store lives in the App Group container when CloudKit is configured
                let groupURL = fm.containerURL(forSecurityApplicationGroupIdentifier: WidgetDataWriter.suiteName)?
                    .appending(path: "Library/Application Support")
                let appSupportURL = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                for dir in [groupURL, appSupportURL].compactMap({ $0 }) {
                    try? fm.removeItem(at: dir.appending(path: "default.store"))
                    try? fm.removeItem(at: dir.appending(path: "default.store-shm"))
                    try? fm.removeItem(at: dir.appending(path: "default.store-wal"))
                }
                do {
                    container = try ModelContainer(for: Schema(allModels))
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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear { pushWatchContext() }
        }
        .modelContainer(modelContainer)
    }

    /// Push latest exercise list + today's plan to Watch via application context.
    private func pushWatchContext() {
        let ctx      = modelContainer.mainContext
        let settings = (try? ctx.fetch(FetchDescriptor<UserSettings>()))?.first
        let weekday  = Calendar.current.component(.weekday, from: .now)
        let todayPlan = settings?.weeklyPlan[weekday] ?? ""
        let useKg     = settings?.useKilograms ?? true

        let exerciseFetch = FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.name)])
        let names  = (try? ctx.fetch(exerciseFetch))?.map(\.name) ?? []
        let unique = Array(Set(names)).sorted()

        // Compute current streak (workouts + cardio)
        let workouts = (try? ctx.fetch(FetchDescriptor<Workout>())) ?? []
        let cardio   = (try? ctx.fetch(FetchDescriptor<CardioSession>())) ?? []
        let streak   = Workout.currentStreak(from: workouts, cardioSessions: Array(cardio.prefix(60)))

        // Write to App Group so Watch complications + UI can read without WCSession
        if let defaults = UserDefaults(suiteName: "group.com.Finbar.FinApp") {
            defaults.set(useKg,       forKey: "watch.useKilograms")
            defaults.set(streak,      forKey: "watch.currentStreak")
            defaults.set(todayPlan,   forKey: "watch.todayPlanName")
        }

        PhoneConnectivityManager.shared.pushExerciseLibrary(
            exercises: Array(unique.prefix(50)),
            todayPlanName: todayPlan,
            useKilograms: useKg,
            currentStreak: streak
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
