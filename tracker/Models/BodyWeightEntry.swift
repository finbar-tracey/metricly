import Foundation
import SwiftData

@Model
final class BodyWeightEntry {
    var date: Date = Date()
    var weight: Double = 0 // always stored in kg

    init(date: Date = .now, weight: Double) {
        self.date = date
        self.weight = weight
    }
}
