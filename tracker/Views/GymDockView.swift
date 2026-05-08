import SwiftUI

/// "Gym Mode" dock pinned to the bottom of `WorkoutDetailView` while a workout
/// is in progress. Always visible, so the primary loop on a gym floor — log
/// set → rest → log next set — never requires scrolling or back-navigation.
///
/// The "active" exercise is the one with the most recent logged set (or the
/// first exercise if nothing's been logged yet). The dock updates automatically
/// as the user logs through their session.
struct GymDockView: View {
    let exercise: Exercise
    let lastSet: ExerciseSet?
    let weightUnitLabel: String
    /// Called when the user taps the "+1 Set" button. Caller should replicate
    /// the most recent working set onto `exercise`.
    let onAddSet: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Left: tap the name area to open the exercise's full detail.
            // Uses the existing `.navigationDestination(for: Exercise.self)`
            // already registered by WorkoutDetailView.
            NavigationLink(value: exercise) {
                HStack(spacing: 12) {
                    iconBadge
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(lastSetSummary)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Right: +1 set quick action
            Button(action: onAddSet) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Set")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(canAddSet ? Color.accentColor : Color.gray.opacity(0.5),
                            in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canAddSet)
            .accessibilityLabel("Add a set to \(exercise.name)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .overlay(
            Rectangle()
                .fill(Color(.separator).opacity(0.6))
                .frame(height: 0.5),
            alignment: .top
        )
    }

    // MARK: - Bits

    private var iconBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(categoryColor.opacity(0.16))
                .frame(width: 36, height: 36)
            Image(systemName: exercise.category?.icon ?? "dumbbell.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(categoryColor)
        }
    }

    private var categoryColor: Color {
        // MuscleGroup.color isn't always defined in this project; fall back to accent
        // for unknown groups to avoid pulling in extra coupling.
        switch exercise.category {
        case .chest:     return .red
        case .back:      return .blue
        case .shoulders: return .orange
        case .biceps:    return .pink
        case .triceps:   return .purple
        case .legs:      return .green
        case .core:      return .teal
        case .cardio:    return .red
        default:         return .accentColor
        }
    }

    /// True if there's enough info on the last set for "+1 Set" to make sense.
    /// For lifts: any working set with weight or reps. For cardio: any with distance/duration.
    private var canAddSet: Bool {
        guard let last = lastSet else {
            // Fall back to letting the caller decide — even with no prior set,
            // they can still navigate to the exercise to add a fresh one.
            return false
        }
        if last.isCardio {
            return (last.distance ?? 0) > 0 || (last.durationSeconds ?? 0) > 0
        }
        return last.weight > 0 || last.reps > 0
    }

    private var lastSetSummary: String {
        guard let last = lastSet else { return "No sets logged yet — tap to begin" }
        if last.isCardio {
            if let d = last.distance, d > 0 {
                return String(format: "Last: %.1f \(weightUnitLabel)", d)
            }
            if let s = last.durationSeconds, s > 0 {
                let m = s / 60, sec = s % 60
                return String(format: "Last: %d:%02d", m, sec)
            }
            return "Last: cardio set"
        }
        let weightStr: String = {
            guard last.weight > 0 else { return "" }
            return String(format: " · %.1f kg", last.weight)
        }()
        let warmupTag = last.isWarmUp ? " · warm-up" : ""
        return "Last: \(last.reps) reps\(weightStr)\(warmupTag)"
    }
}
