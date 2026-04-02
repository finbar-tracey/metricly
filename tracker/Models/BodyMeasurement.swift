import Foundation
import SwiftData

@Model
final class BodyMeasurement {
    var date: Date
    var site: String
    var value: Double // Always stored in cm

    init(date: Date = .now, site: String, value: Double) {
        self.date = date
        self.site = site
        self.value = value
    }

    static let allSites = [
        "Neck", "Chest", "Waist", "Hips",
        "Left Bicep", "Right Bicep",
        "Left Thigh", "Right Thigh",
        "Left Calf", "Right Calf"
    ]
}
