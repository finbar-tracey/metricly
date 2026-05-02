import Foundation
import SwiftData
import CoreLocation
import SwiftUI

// MARK: - PaceZone

enum PaceZone: String {
    case speed      = "Speed"
    case threshold  = "Threshold"
    case tempo      = "Tempo"
    case aerobic    = "Aerobic"
    case easy       = "Easy"
    case recovery   = "Recovery"

    var color: Color {
        switch self {
        case .speed:     return Color(red: 0.85, green: 0.1, blue: 0.1)   // red
        case .threshold: return Color(red: 0.95, green: 0.45, blue: 0.1)  // deep orange
        case .tempo:     return Color(red: 0.95, green: 0.7, blue: 0.1)   // amber
        case .aerobic:   return Color(red: 0.2, green: 0.7, blue: 0.3)    // green
        case .easy:      return Color(red: 0.2, green: 0.6, blue: 0.9)    // blue
        case .recovery:  return Color(red: 0.6, green: 0.6, blue: 0.8)    // slate
        }
    }

    /// Classify a pace (seconds per km). Typical amateur ranges; runners who set goals will
    /// naturally calibrate their sense of zones to these thresholds.
    static func zone(for paceSecPerKm: Double) -> PaceZone {
        switch paceSecPerKm {
        case ..<240:   return .speed       // < 4:00/km
        case 240..<270: return .threshold  // 4:00–4:30
        case 270..<330: return .tempo      // 4:30–5:30
        case 330..<390: return .aerobic    // 5:30–6:30
        case 390..<480: return .easy       // 6:30–8:00
        default:        return .recovery   // > 8:00
        }
    }
}

// MARK: - CardioType

enum CardioType: String, CaseIterable, Identifiable, Codable {
    case outdoorRun   = "Outdoor Run"
    case indoorRun    = "Indoor Run"
    case outdoorWalk  = "Outdoor Walk"
    case indoorWalk   = "Indoor Walk"
    case outdoorCycle = "Outdoor Cycle"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .outdoorRun, .indoorRun:    return "figure.run"
        case .outdoorWalk, .indoorWalk:  return "figure.walk"
        case .outdoorCycle:              return "figure.outdoor.cycle"
        }
    }

    var color: Color {
        switch self {
        case .outdoorRun, .indoorRun:    return .orange
        case .outdoorWalk, .indoorWalk:  return .green
        case .outdoorCycle:              return .blue
        }
    }

    var isIndoor: Bool {
        self == .indoorRun || self == .indoorWalk
    }

    var usesGPS: Bool { !isIndoor }

    var shortName: String {
        switch self {
        case .outdoorRun:   return "Run"
        case .indoorRun:    return "Treadmill"
        case .outdoorWalk:  return "Walk"
        case .indoorWalk:   return "Walk"
        case .outdoorCycle: return "Cycle"
        }
    }
}

// MARK: - CardioSplit

struct CardioSplit: Codable, Identifiable {
    var id: Int                          // 1-based split number
    var splitDistanceMeters: Double      // distance covered in this split
    var cumulativeDistanceMeters: Double
    var durationSeconds: Double          // time for this split
    var cumulativeDurationSeconds: Double
    var avgHeartRate: Double?

    var paceSecondsPerKm: Double {
        guard splitDistanceMeters > 0 else { return 0 }
        return durationSeconds / (splitDistanceMeters / 1000)
    }

    var paceSecondsPerMile: Double {
        guard splitDistanceMeters > 0 else { return 0 }
        return durationSeconds / (splitDistanceMeters / 1609.344)
    }

    func formattedPace(useKm: Bool) -> String {
        let raw = useKm ? paceSecondsPerKm : paceSecondsPerMile
        guard raw > 0 && raw < 3600 else { return "--:--" }
        return String(format: "%d:%02d", Int(raw) / 60, Int(raw) % 60)
    }

    func formattedDuration() -> String {
        let m = Int(durationSeconds) / 60
        let s = Int(durationSeconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - CardioRoutePoint

struct CardioRoutePoint: Codable {
    var latitude: Double
    var longitude: Double
    var altitude: Double
    var timestamp: Date

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(location: CLLocation) {
        latitude  = location.coordinate.latitude
        longitude = location.coordinate.longitude
        altitude  = location.altitude
        timestamp = location.timestamp
    }
}

// MARK: - CardioSession

@Model
final class CardioSession {
    var id: UUID        = UUID()
    var date: Date      = Date()
    var title: String   = ""
    var cardioType: String = CardioType.outdoorRun.rawValue

    var durationSeconds: Double    = 0
    var distanceMeters: Double     = 0
    var elevationGainMeters: Double = 0
    var caloriesBurned: Double?    = nil
    var avgHeartRate: Double?      = nil
    var maxHeartRate: Double?      = nil
    var notes: String              = ""

    // Stored as JSON blobs so SwiftData doesn't need to know the types
    var routeData: Data?  = nil
    var splitsData: Data? = nil

    init(
        date: Date = .now,
        title: String = "",
        type: CardioType = .outdoorRun,
        durationSeconds: Double = 0,
        distanceMeters: Double = 0,
        elevationGainMeters: Double = 0
    ) {
        self.date               = date
        self.title              = title.isEmpty ? type.shortName : title
        self.cardioType         = type.rawValue
        self.durationSeconds    = durationSeconds
        self.distanceMeters     = distanceMeters
        self.elevationGainMeters = elevationGainMeters
    }

    // MARK: - Derived

    var type: CardioType {
        CardioType(rawValue: cardioType) ?? .outdoorRun
    }

    var routePoints: [CardioRoutePoint] {
        get { (try? JSONDecoder().decode([CardioRoutePoint].self, from: routeData ?? Data())) ?? [] }
        set { routeData = try? JSONEncoder().encode(newValue) }
    }

    var splits: [CardioSplit] {
        get { (try? JSONDecoder().decode([CardioSplit].self, from: splitsData ?? Data())) ?? [] }
        set { splitsData = try? JSONEncoder().encode(newValue) }
    }

    var avgPaceSecPerKm: Double {
        guard distanceMeters > 0 else { return 0 }
        return durationSeconds / (distanceMeters / 1000)
    }

    var avgPaceSecPerMile: Double {
        guard distanceMeters > 0 else { return 0 }
        return durationSeconds / (distanceMeters / 1609.344)
    }

    func estimatedCalories(bodyWeightKg: Double = 70) -> Double {
        let met: Double
        switch type {
        case .outdoorRun, .indoorRun:   met = 9.8
        case .outdoorWalk, .indoorWalk: met = 3.5
        case .outdoorCycle:             met = 7.5
        }
        return met * bodyWeightKg * (durationSeconds / 3600)
    }

    func formattedDistance(useKm: Bool) -> String {
        useKm
            ? String(format: "%.2f km", distanceMeters / 1000)
            : String(format: "%.2f mi", distanceMeters / 1609.344)
    }

    func formattedPace(useKm: Bool) -> String {
        let pace = useKm ? avgPaceSecPerKm : avgPaceSecPerMile
        guard pace > 0 && pace < 3600 else { return "--:--" }
        return String(format: "%d:%02d / %@", Int(pace) / 60, Int(pace) % 60, useKm ? "km" : "mi")
    }

    var formattedDuration: String {
        let h = Int(durationSeconds) / 3600
        let m = Int(durationSeconds) % 3600 / 60
        let s = Int(durationSeconds) % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}
