import SwiftUI

/// Typed deep-link routing (replaces `NotificationCenter` tab posts).
@MainActor @Observable
final class AppRouter {
    static let shared = AppRouter()

    private(set) var openTrainingTabSignal: UInt = 0
    private(set) var openInsightsTabSignal: UInt = 0

    func openTrainingTab() {
        openTrainingTabSignal &+= 1
    }

    func openInsightsTab() {
        openInsightsTabSignal &+= 1
    }
}
