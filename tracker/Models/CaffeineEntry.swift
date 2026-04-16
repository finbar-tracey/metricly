import Foundation
import SwiftData

@Model
final class CaffeineEntry {
    var date: Date
    var milligrams: Double // always stored in mg
    var source: String     // "Coffee", "Espresso", "Tea", "Energy Drink", "Pre-Workout", "Other"

    init(date: Date = .now, milligrams: Double, source: String) {
        self.date = date
        self.milligrams = milligrams
        self.source = source
    }

    /// Remaining caffeine (mg) at a given point in time using 5-hour half-life
    func remainingCaffeine(at time: Date = .now) -> Double {
        let elapsed = time.timeIntervalSince(date)
        guard elapsed >= 0 else { return 0 }
        let halfLife: TimeInterval = 5 * 3600 // 5 hours
        return milligrams * pow(0.5, elapsed / halfLife)
    }

    /// Common caffeine presets
    static let presets: [(name: String, mg: Double, icon: String)] = [
        ("Coffee",        95,  "cup.and.saucer.fill"),
        ("Espresso",      63,  "cup.and.saucer.fill"),
        ("Tea",           47,  "leaf.fill"),
        ("Energy Drink", 160,  "bolt.fill"),
        ("Pre-Workout",  200,  "figure.run"),
        ("Other",          0,  "pill.fill")
    ]
}
