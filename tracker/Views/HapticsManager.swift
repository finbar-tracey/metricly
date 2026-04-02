import UIKit
import AudioToolbox

enum HapticsManager {
    // MARK: - Set Completion
    static func setAdded() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func warmUpSetAdded() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Personal Record
    static func personalRecord() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        // Double haptic for emphasis
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1.0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 0.7)
        }
        // Celebration sound
        AudioServicesPlaySystemSound(1025) // Fanfare-style
    }

    // MARK: - Timer
    static func timerComplete() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        AudioServicesPlayAlertSound(SystemSoundID(1005))
    }

    static func timerCountdown() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func timerWarning() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        AudioServicesPlaySystemSound(1057) // Tock
    }

    // MARK: - Workout
    static func workoutStarted() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        AudioServicesPlaySystemSound(1004) // Key press
    }

    static func workoutFinished() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
        AudioServicesPlaySystemSound(1025)
    }

    // MARK: - General
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func selectionChanged() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func lightTap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func heavyTap() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    // MARK: - Achievement
    static func achievementUnlocked() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1.0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.8)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.5)
        }
        AudioServicesPlaySystemSound(1025)
    }
}
