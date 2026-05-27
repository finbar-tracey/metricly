import Foundation
import SwiftData

/// User-reported muscle soreness on a 0–4 scale. Captured after a
/// workout (FinishWorkoutSheet) and read by RecoveryEngine as a third
/// intensity signal alongside training volume and RPE.
///
/// Stored as a raw String for the muscle group (CloudKit-safe pattern
/// used throughout the schema). The computed `group` property bridges
/// back to MuscleGroup.
@Model
final class SorenessEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    /// MuscleGroup.rawValue — stored as raw string so reordering or
    /// renaming the enum doesn't corrupt existing entries on CloudKit.
    var muscleGroupRaw: String = MuscleGroup.other.rawValue
    /// 0 = none, 1 = mild, 2 = moderate, 3 = significant, 4 = severe.
    var level: Int = 0
    var note: String = ""

    init(
        id: UUID = UUID(),
        date: Date = .now,
        group: MuscleGroup,
        level: Int,
        note: String = ""
    ) {
        self.id = id
        self.date = date
        self.muscleGroupRaw = group.rawValue
        self.level = level
        self.note = note
    }

    /// Bridge to the enum form. Falls back to `.other` if the raw value
    /// no longer matches any known case (defensive against future
    /// renames; the data still loads, just buckets to "other").
    var group: MuscleGroup {
        MuscleGroup(rawValue: muscleGroupRaw) ?? .other
    }
}

extension SorenessEntry {
    enum Level: Int, CaseIterable, Identifiable {
        case none = 0, mild, moderate, significant, severe
        var id: Int { rawValue }

        var label: String {
            switch self {
            case .none:        return "None"
            case .mild:        return "Mild"
            case .moderate:    return "Moderate"
            case .significant: return "Significant"
            case .severe:      return "Severe"
            }
        }

        var sfSymbol: String {
            switch self {
            case .none:        return "checkmark.circle"
            case .mild:        return "circle.lefthalf.filled"
            case .moderate:    return "circle.fill"
            case .significant: return "exclamationmark.circle.fill"
            case .severe:      return "exclamationmark.triangle.fill"
            }
        }
    }
}
