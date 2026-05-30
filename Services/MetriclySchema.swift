import Foundation
import SwiftData

/// Single source of truth for the Metricly SwiftData schema.
///
/// Both the main app and any App Intents must use the same model set —
/// previously each intent declared a smaller schema, which risked
/// CloudKit container divergence, store-shape mismatches, and silently
/// reading from a different local file than the main app.
///
/// Adding a new `@Model` type? Add it to the latest schema version
/// (currently `MetriclySchemaV4`). For a purely-additive change (a new
/// @Model class, or a new optional field on an existing one) SwiftData
/// can migrate automatically — append a `.lightweight` stage to the
/// migration plan and you're done.
///
/// **Versioned-schema policy (important).** Each `MetriclySchemaVN`
/// below references the *live* model classes (`Workout.self`,
/// `CardioSession.self`, etc.) rather than a frozen per-version
/// snapshot. That's deliberate and works fine for the changes we've
/// shipped so far — every one has been an additive optional field or a
/// new model. Lightweight migration handles those by inferring the
/// diff from the type system, and the live class is good enough.
///
/// For any **non-additive** change (rename, change a field's type,
/// change a relationship's cascade, drop a field, narrow an optional),
/// the live-class shortcut breaks: V1 would no longer accurately
/// describe what V1 stores held on disk, and SwiftData's inference
/// can't reconstruct the old shape. The fix at that point is to
/// freeze the affected model under a per-version `models/` subfolder
/// — e.g. `MetriclySchemaV3.Workout` — and use a `.custom` stage with
/// explicit field copies. Don't lean on the existing migration tests
/// as proof of safety for that future change; they cover the additive
/// path only.
enum MetriclySchema {

    /// Complete model set — keep in sync with trackerApp.init.
    /// Order is irrelevant; SwiftData reads this as a Set.
    static let allModels: [any PersistentModel.Type] = MetriclySchemaV4.models

    static var schema: Schema { Schema(versionedSchema: MetriclySchemaV4.self) }

    /// Build a CloudKit-backed container with the full schema. App
    /// Intents call this so they share the user's iCloud-synced store
    /// with the main app rather than creating a parallel local one.
    ///
    /// Falls back to a local-only container if CloudKit init fails so
    /// intents still function when the user has iCloud disabled.
    static func makeSharedContainer() throws -> ModelContainer {
        let cloud = ModelConfiguration(cloudKitDatabase: .automatic)
        if let cloudContainer = try? ModelContainer(
            for: schema,
            migrationPlan: MetriclyMigrationPlan.self,
            configurations: cloud
        ) {
            return cloudContainer
        }
        return try ModelContainer(
            for: schema,
            migrationPlan: MetriclyMigrationPlan.self
        )
    }
}

// MARK: - Versioned schema (V1)
//
// First versioned slice of the schema. Today this is identical to what
// shipped — purpose is the boilerplate so the next migration is a small
// additive PR (V2 + a stage) rather than a big-bang restructure on a
// store that holds years of user data.
//
// When you need to migrate:
//   1. Copy this V1 block to a V2 below.
//   2. Edit V2's models — add fields, rename, etc.
//   3. Add a `MigrationStage` (lightweight or custom) between V1 and V2.
//   4. Append the stage to `MetriclyMigrationPlan.stages`.
//   5. Update `MetriclySchema.schema` to point at the new latest version.

enum MetriclySchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
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
            CardioSession.self,
        ]
    }
}

// V2 adds `SorenessEntry` for user-reported muscle soreness, which the
// recovery engine consumes as a third intensity signal (alongside
// volume and RPE). Purely additive — no migration logic needed.

enum MetriclySchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        MetriclySchemaV1.models + [SorenessEntry.self]
    }
}

// V3 adds `PlanComplianceEvent` — daily snapshots of "did the user
// follow the engine's suggestion?" used to bias future plan confidence.
// Purely additive; no data transformation required.

enum MetriclySchemaV3: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(3, 0, 0) }

    static var models: [any PersistentModel.Type] {
        MetriclySchemaV2.models + [PlanComplianceEvent.self]
    }
}

// V4 adds `WorkoutFeedbackEvent` — user-reported "how did that
// workout feel?" capture from FinishWorkoutSheet. Sits alongside
// PlanComplianceEvent in the trust-cal data layer; compliance is
// inferred, feedback is reported. Purely additive; no data
// transformation required.

enum MetriclySchemaV4: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(4, 0, 0) }

    static var models: [any PersistentModel.Type] {
        MetriclySchemaV3.models + [WorkoutFeedbackEvent.self]
    }
}

// MARK: - Migration plan
//
// SwiftData walks this chain on container init, replaying any stage
// whose endpoints span the user's persisted version up to the active
// latest. Append new stages here; never remove an older one.

enum MetriclyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [MetriclySchemaV1.self, MetriclySchemaV2.self,
         MetriclySchemaV3.self, MetriclySchemaV4.self]
    }

    static var stages: [MigrationStage] {
        [
            // V1 → V2: lightweight (SwiftData auto-creates the new
            // SorenessEntry table; no data transformation required).
            .lightweight(fromVersion: MetriclySchemaV1.self, toVersion: MetriclySchemaV2.self),
            // V2 → V3: lightweight (adds PlanComplianceEvent table).
            .lightweight(fromVersion: MetriclySchemaV2.self, toVersion: MetriclySchemaV3.self),
            // V3 → V4: lightweight (adds WorkoutFeedbackEvent table).
            .lightweight(fromVersion: MetriclySchemaV3.self, toVersion: MetriclySchemaV4.self),
        ]
    }
}
