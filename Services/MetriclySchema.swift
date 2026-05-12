import Foundation
import SwiftData

/// Single source of truth for the Metricly SwiftData schema.
///
/// Both the main app and any App Intents must use the same model set —
/// previously each intent declared a smaller schema, which risked
/// CloudKit container divergence, store-shape mismatches, and silently
/// reading from a different local file than the main app.
///
/// Adding a new `@Model` type? Add it here once. Every container builder
/// in the project reads this list.
enum MetriclySchema {

    /// Complete model set — keep in sync with trackerApp.init.
    /// Order is irrelevant; SwiftData reads this as a Set.
    static let allModels: [any PersistentModel.Type] = [
        Workout.self,
        Exercise.self,
        ExerciseSet.self,
        UserSettings.self,
        BodyWeightEntry.self,
        TrainingProgram.self,
        ProgramDay.self,
        ProgramExercise.self,
        BodyMeasurement.self,
        LiftGoal.self,
        ProgressPhoto.self,
        CaffeineEntry.self,
        WaterEntry.self,
        CreatineEntry.self,
        ManualActivity.self,
        CardioSession.self
    ]

    static var schema: Schema { Schema(allModels) }

    /// Build a CloudKit-backed container with the full schema. App
    /// Intents call this so they share the user's iCloud-synced store
    /// with the main app rather than creating a parallel local one.
    ///
    /// Falls back to a local-only container if CloudKit init fails so
    /// intents still function when the user has iCloud disabled.
    static func makeSharedContainer() throws -> ModelContainer {
        let cloud = ModelConfiguration(cloudKitDatabase: .automatic)
        if let cloudContainer = try? ModelContainer(for: schema, configurations: cloud) {
            return cloudContainer
        }
        return try ModelContainer(for: schema)
    }
}
