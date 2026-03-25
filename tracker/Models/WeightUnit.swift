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

private struct WeightUnitKey: EnvironmentKey {
    static let defaultValue: WeightUnit = .kg
}

extension EnvironmentValues {
    var weightUnit: WeightUnit {
        get { self[WeightUnitKey.self] }
        set { self[WeightUnitKey.self] = newValue }
    }
}
