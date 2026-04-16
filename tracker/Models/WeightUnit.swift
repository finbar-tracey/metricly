import SwiftUI

enum WeightUnit: String {
    case kg, lbs

    var label: String {
        rawValue
    }

    func display(_ kg: Double) -> Double {
        switch self {
        case .kg: return kg
        case .lbs: return kg * 2.20462
        }
    }

    func toKg(_ value: Double) -> Double {
        switch self {
        case .kg: return value
        case .lbs: return value / 2.20462
        }
    }

    func format(_ kg: Double) -> String {
        let value = display(kg)
        return "\(String(format: "%.1f", value)) \(label)"
    }

    func formatShort(_ kg: Double) -> String {
        let value = display(kg)
        return "\(String(format: "%.0f", value))\(label)"
    }
}

// MARK: - Distance Unit (derived from weight unit)

enum DistanceUnit: String {
    case km, mi

    var label: String { rawValue }

    /// Convert stored km to display value
    func display(_ km: Double) -> Double {
        switch self {
        case .km: return km
        case .mi: return km * 0.621371
        }
    }

    /// Convert display value back to km for storage
    func toKm(_ value: Double) -> Double {
        switch self {
        case .km: return value
        case .mi: return value / 0.621371
        }
    }

    func format(_ km: Double) -> String {
        let value = display(km)
        if value >= 1.0 {
            return String(format: "%.2f %@", value, label)
        }
        switch self {
        case .km: return String(format: "%d m", Int(km * 1000))
        case .mi: return String(format: "%.2f %@", value, label)
        }
    }

    var stepSize: Double {
        switch self {
        case .km: return 0.5
        case .mi: return 0.25
        }
    }
}

extension WeightUnit {
    var distanceUnit: DistanceUnit {
        switch self {
        case .kg: return .km
        case .lbs: return .mi
        }
    }
}

private struct WeightUnitKey: EnvironmentKey {
    static let defaultValue: WeightUnit = .kg
}

extension EnvironmentValues {
    var weightUnit: WeightUnit {
        get { self[WeightUnitKey.self] }
        set { self[WeightUnitKey.self] = newValue }
    }
}
