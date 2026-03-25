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
    init() {
        MetriclyShortcutsProvider.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Workout.self, UserSettings.self, BodyWeightEntry.self, TrainingProgram.self], isAutosaveEnabled: true)
    }
}
