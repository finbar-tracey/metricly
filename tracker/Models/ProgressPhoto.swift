import Foundation
import SwiftData

@Model
final class ProgressPhoto {
    var date: Date = Date()
    var imageData: Data = Data()
    var notes: String = ""
    var category: String = "Front"

    init(date: Date = .now, imageData: Data, notes: String = "", category: String = "Front") {
        self.date = date
        self.imageData = imageData
        self.notes = notes
        self.category = category
    }
}
