import Foundation
import SwiftData

@Model
final class ManualActivity {
    var date: Date
    var activityType: String // raw value of ActivityType
    var durationMinutes: Int
    var notes: String = ""
    var caloriesBurned: Int? = nil

    init(date: Date = .now, activityType: String, durationMinutes: Int, notes: String = "", caloriesBurned: Int? = nil) {
        self.date = date
        self.activityType = activityType
        self.durationMinutes = durationMinutes
        self.notes = notes
        self.caloriesBurned = caloriesBurned
    }

    var type: ActivityType {
        ActivityType(rawValue: activityType) ?? .other
    }

    enum ActivityType: String, CaseIterable, Identifiable {
        case walk = "Walk"
        case run = "Run"
        case bike = "Bike"
        case swim = "Swim"
        case hike = "Hike"
        case stretch = "Stretch"
        case yoga = "Yoga"
        case sport = "Sport"
        case other = "Other"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .walk: return "figure.walk"
            case .run: return "figure.run"
            case .bike: return "figure.outdoor.cycle"
            case .swim: return "figure.pool.swim"
            case .hike: return "figure.hiking"
            case .stretch: return "figure.flexibility"
            case .yoga: return "figure.yoga"
            case .sport: return "sportscourt"
            case .other: return "figure.mixed.cardio"
            }
        }

        var color: String {
            switch self {
            case .walk: return "green"
            case .run: return "orange"
            case .bike: return "blue"
            case .swim: return "cyan"
            case .hike: return "brown"
            case .stretch: return "purple"
            case .yoga: return "indigo"
            case .sport: return "red"
            case .other: return "gray"
            }
        }
    }
}
