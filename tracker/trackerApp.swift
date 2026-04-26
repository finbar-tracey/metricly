//
//  trackerApp.swift
//  tracker
//
//  Created by Finbar Tracey on 04/03/2026.
//

import SwiftUI
import SwiftData
import AppIntents

@main
struct trackerApp: App {
    let modelContainer: ModelContainer

    init() {
        MetriclyShortcutsProvider.updateAppShortcutParameters()

        let container = try! ModelContainer(for: Workout.self, Exercise.self, ExerciseSet.self, UserSettings.self, BodyWeightEntry.self, TrainingProgram.self, ProgramDay.self, ProgramExercise.self, BodyMeasurement.self, LiftGoal.self, ProgressPhoto.self, CaffeineEntry.self, WaterEntry.self, CreatineEntry.self, ManualActivity.self)
        // Seed UserSettings once so views never need to insert from computed properties
        let context = container.mainContext
        let descriptor = FetchDescriptor<UserSettings>()
        if (try? context.fetchCount(descriptor)) == 0 {
            context.insert(UserSettings())
        }
        self.modelContainer = container
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
