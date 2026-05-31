import Foundation
import SwiftData

/// Pure body-measurement trend math for `BodyMeasurementsView`.
enum BodyMeasurementsEngine {

    static func siteEntries(allEntries: [BodyMeasurement], site: String) -> [BodyMeasurement] {
        allEntries.filter { $0.site == site }
    }

    static func chartEntries(siteEntries: [BodyMeasurement], maxCount: Int = 90) -> [BodyMeasurement] {
        Array(siteEntries.suffix(maxCount).reversed())
    }

    static func chartYDomain(displayLengths: [Double]) -> ClosedRange<Double> {
        guard let minVal = displayLengths.min(), let maxVal = displayLengths.max() else { return 0...100 }
        let padding = Swift.max(0.5, (maxVal - minVal) * 0.15)
        return (minVal - padding)...(maxVal + padding)
    }

    static func lowestCm(siteEntries: [BodyMeasurement]) -> Double? {
        siteEntries.map(\.value).min()
    }

    static func highestCm(siteEntries: [BodyMeasurement]) -> Double? {
        siteEntries.map(\.value).max()
    }

    static func valueChangeCm(
        siteEntries: [BodyMeasurement],
        lookbackDays: Int = 30,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Double? {
        guard let latest = siteEntries.first else { return nil }
        let cutoff = calendar.date(byAdding: .day, value: -lookbackDays, to: now) ?? .distantPast
        guard let oldest = siteEntries.last(where: { $0.date <= cutoff }) ?? siteEntries.last,
              oldest.persistentModelID != latest.persistentModelID else { return nil }
        return latest.value - oldest.value
    }

    static func formatChange(
        changeCm: Double,
        displayLength: (Double) -> Double,
        lengthLabel: String
    ) -> String {
        let value = displayLength(changeCm)
        let sign = value >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", value)) \(lengthLabel)"
    }

}
