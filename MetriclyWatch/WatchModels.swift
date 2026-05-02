import Foundation
import SwiftUI

// MARK: - Shared keys (App Group UserDefaults)

enum WatchSharedKeys {
    static let suite            = "group.com.Finbar.FinApp"
    static let recentExercises  = "watch.recentExercises"   // [String]
    static let todayPlanName    = "watch.todayPlanName"      // String
    static let useKilograms     = "watch.useKilograms"       // Bool  (default true)
    static let currentStreak    = "watch.currentStreak"      // Int
    static let restDuration     = "watch.restDuration"       // Int seconds (default 60)
}

// MARK: - In-progress gym workout (Watch memory model)

struct WatchSetRecord: Identifiable, Codable {
    var id       = UUID()
    var reps     : Int
    var weightKg : Double
    var isWarmUp : Bool = false
}

struct WatchExerciseRecord: Identifiable, Codable {
    var id   = UUID()
    var name : String
    var sets : [WatchSetRecord] = []
}

// WatchWorkoutPayload, WatchCardioPayload, WatchMessageKey, WatchMessageType
// are defined in Services/WatchSyncModels.swift (compiled into both targets).

// MARK: - Heart rate zone

enum HRZone: String {
    case resting  = "Rest"
    case fat      = "Fat Burn"
    case cardio   = "Cardio"
    case peak     = "Peak"
    case max      = "Max"

    var color: any ShapeStyle {
        switch self {
        case .resting:  return AnyShapeStyle(.gray)
        case .fat:      return AnyShapeStyle(.blue)
        case .cardio:   return AnyShapeStyle(.green)
        case .peak:     return AnyShapeStyle(.orange)
        case .max:      return AnyShapeStyle(.red)
        }
    }

    static func zone(for bpm: Double, maxHR: Double = 190) -> HRZone {
        let pct = bpm / maxHR
        switch pct {
        case ..<0.50:  return .resting
        case 0.50..<0.60: return .fat
        case 0.60..<0.70: return .cardio
        case 0.70..<0.85: return .peak
        default:          return .max
        }
    }
}

// MARK: - Formatting helpers (Watch-side, no WeightUnit env)

func formatWeight(_ kg: Double, useKg: Bool) -> String {
    if useKg {
        let val = kg.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", kg) : String(format: "%.1f", kg)
        return "\(val) kg"
    } else {
        let lbs = kg * 2.20462
        let val = lbs.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", lbs) : String(format: "%.1f", lbs)
        return "\(val) lb"
    }
}

func formatDuration(_ seconds: Int) -> String {
    let h = seconds / 3600
    let m = (seconds % 3600) / 60
    let s = seconds % 60
    if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
    return String(format: "%d:%02d", m, s)
}

func formatPace(distanceMeters: Double, elapsedSeconds: Int, useKm: Bool) -> String {
    guard distanceMeters > 10, elapsedSeconds > 0 else { return "--:--" }
    let unit = useKm ? 1000.0 : 1609.344
    let paceSeconds = Double(elapsedSeconds) / (distanceMeters / unit)
    guard paceSeconds > 0 && paceSeconds < 3600 else { return "--:--" }
    return String(format: "%d:%02d", Int(paceSeconds) / 60, Int(paceSeconds) % 60)
}
