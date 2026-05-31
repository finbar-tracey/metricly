import Foundation

/// Barbell plate loading math for `PlateCalculatorView`.
enum PlateCalculatorEngine {

    static let availablePlatesKg: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]
    static let quickWeightsKg: [Double] = [40, 60, 80, 100, 120, 140, 160, 180]

    static func targetKg(displayValue: String, unit: WeightUnit) -> Double {
        guard let value = Double(displayValue), value > 0 else { return 0 }
        return unit.toKg(value)
    }

    static func platesPerSide(targetKg: Double, barWeightKg: Double, platesKg: [Double] = availablePlatesKg) -> [Double] {
        let remaining = targetKg - barWeightKg
        guard remaining > 0 else { return [] }
        var perSide = remaining / 2.0
        var result: [Double] = []
        for plate in platesKg {
            while perSide >= plate - 0.001 {
                result.append(plate)
                perSide -= plate
            }
        }
        return result
    }

    static func actualWeightKg(barWeightKg: Double, platesPerSide: [Double]) -> Double {
        barWeightKg + platesPerSide.reduce(0, +) * 2
    }
}
