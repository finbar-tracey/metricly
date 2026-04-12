import Foundation

enum HealthFormatters {
    static func formatSteps(_ steps: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: steps)) ?? "0"
    }

    static func formatSleepShort(_ minutes: Double) -> String {
        let h = Int(minutes) / 60
        let m = Int(minutes) % 60
        if h == 0 && m == 0 { return "—" }
        if h == 0 { return "\(m)m" }
        return "\(h)h\(m > 0 ? " \(m)m" : "")"
    }

    static func formatSleepDuration(_ minutes: Double) -> String {
        let h = Int(minutes) / 60
        let m = Int(minutes) % 60
        return "\(h) hours \(m) minutes"
    }
}
