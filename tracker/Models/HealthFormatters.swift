import Foundation

enum HealthFormatters {
    private static let intFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()

    static func formatSteps(_ steps: Double) -> String {
        intFormatter.string(from: NSNumber(value: steps)) ?? "0"
    }

    static func formatSleepShort(_ minutes: Double) -> String {
        let h = Int(minutes) / 60
        let m = Int(minutes) % 60
        if h == 0 && m == 0 { return "—" }
        if h == 0 { return "\(m)m" }
        return "\(h)h\(m > 0 ? " \(m)m" : "")"
    }

    static func formatDistance(_ km: Double) -> String {
        if km < 0.01 { return "—" }
        return String(format: "%.1f km", km)
    }

    static func formatDistance(_ km: Double, unit: DistanceUnit) -> String {
        if km < 0.01 { return "—" }
        return String(format: "%.1f \(unit.label)", unit.display(km))
    }

    static func formatCalories(_ kcal: Double) -> String {
        (intFormatter.string(from: NSNumber(value: kcal)) ?? "0") + " kcal"
    }

    static func formatSleepDuration(_ minutes: Double) -> String {
        let h = Int(minutes) / 60
        let m = Int(minutes) % 60
        return "\(h) hours \(m) minutes"
    }
}
