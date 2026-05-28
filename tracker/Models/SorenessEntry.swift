import Foundation
import SwiftData
import SwiftUI

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

        /// Display tint for soreness severity. Lives on the enum so the
        /// FinishWorkoutSheet capture UI and the MuscleRecoveryView
        /// readout can't drift apart — they were byte-for-byte identical
        /// 5-level ramps before this consolidation.
        ///
        /// Color intent (calibrated against AppTheme.Signal where possible):
        ///   .none        — green       (no signal)
        ///   .mild        — yellow      (low signal, not strain)
        ///   .moderate    — orange      (notable, train carefully)
        ///   .significant — red-orange  (recovery prioritised)
        ///   .severe      — red         (don't train this group)
        var tint: Color {
            switch self {
            case .none:        return .green
            case .mild:        return Color(red: 0.85, green: 0.80, blue: 0.20)
            case .moderate:    return .orange
            case .significant: return Color(red: 0.95, green: 0.40, blue: 0.20)
            case .severe:      return .red
            }
        }

        /// Convenience: clamp a raw Int level (0–4) to the closest enum
        /// case and return its tint. Used by both capture and readout
        /// surfaces that work with the raw `Int` from `SorenessEntry.level`.
        static func tint(forLevel raw: Int) -> Color {
            (Level(rawValue: max(0, min(4, raw))) ?? .none).tint
        }
    }
}
