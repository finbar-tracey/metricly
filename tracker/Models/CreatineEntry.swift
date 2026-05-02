import Foundation
import SwiftData

@Model
final class CreatineEntry {
    var date: Date = Date()
    var grams: Double = 5.0 // typically 3-5g

    init(date: Date = .now, grams: Double = 5.0) {
        self.date = date
        self.grams = grams
    }

    /// Default daily dose in grams
    static let defaultDose: Double = 5.0
}
