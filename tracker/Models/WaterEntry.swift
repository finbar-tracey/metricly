import Foundation
import SwiftData

@Model
final class WaterEntry {
    var date: Date = Date()
    var milliliters: Double = 0 // always stored in ml

    init(date: Date = .now, milliliters: Double) {
        self.date = date
        self.milliliters = milliliters
    }

    /// Common presets (ml)
    static let presets: [(label: String, ml: Double, icon: String)] = [
        ("Glass",      250,  "drop.fill"),
        ("Small Bottle", 500, "waterbottle.fill"),
        ("Large Bottle", 750, "waterbottle.fill"),
        ("Liter",      1000, "drop.circle.fill"),
    ]

    /// Daily goal in ml (default ~2.5L / ~84 oz)
    static let defaultGoalMl: Double = 2500
}
