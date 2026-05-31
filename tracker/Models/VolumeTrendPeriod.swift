import Foundation

/// Weekly vs monthly volume trend windows (not the same as `DetailTimeRange` 7D/30D/90D).
enum VolumeTrendPeriod: String, CaseIterable {
    case weekly = "Weekly"
    case monthly = "Monthly"
}
