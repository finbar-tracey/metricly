import Foundation
import SwiftData

@Model
final class CaffeineEntry {
    var date: Date = Date()
    var milligrams: Double = 0 // always stored in mg
    var source: String = ""    // "Coffee", "Espresso", "Tea", "Energy Drink", "Pre-Workout", "Other"

    init(date: Date = .now, milligrams: Double, source: String) {
        self.date = date
        self.milligrams = milligrams
        self.source = source
    }

    /// Default half-life: 5 hours (normal metabolizer)
    static let defaultHalfLifeHours: Double = 5.0

    /// Remaining caffeine (mg) at a given point in time
    func remainingCaffeine(at time: Date = .now, halfLifeHours: Double = CaffeineEntry.defaultHalfLifeHours) -> Double {
        let elapsed = time.timeIntervalSince(date)
        guard elapsed >= 0 else { return 0 }
        let halfLife: TimeInterval = halfLifeHours * 3600
        return milligrams * pow(0.5, elapsed / halfLife)
    }

    /// Common caffeine presets
    static let presets: [(name: String, mg: Double, icon: String)] = [
        ("Coffee",        95,  "cup.and.saucer.fill"),
        ("Espresso",      63,  "cup.and.saucer.fill"),
        ("Cold Brew",    200,  "mug.fill"),
        ("Tea",           47,  "leaf.fill"),
        ("Matcha",        70,  "leaf.circle.fill"),
        ("Energy Drink", 160,  "bolt.fill"),
        ("Soda",          40,  "cup.and.heat.waves.fill"),
        ("Pre-Workout",  200,  "figure.run"),
        ("Chocolate",     25,  "birthday.cake.fill"),
        ("Decaf",          5,  "cup.and.saucer"),
        ("Other",          0,  "pill.fill")
    ]

    /// Caffeine sensitivity levels
    enum Sensitivity: String, CaseIterable, Identifiable {
        case slow = "Slow"
        case normal = "Normal"
        case fast = "Fast"

        var id: String { rawValue }

        var halfLifeHours: Double {
            switch self {
            case .slow: return 7.0
            case .normal: return 5.0
            case .fast: return 3.0
            }
        }

        var description: String {
            switch self {
            case .slow: return "~7h half-life"
            case .normal: return "~5h half-life"
            case .fast: return "~3h half-life"
            }
        }
    }
}
