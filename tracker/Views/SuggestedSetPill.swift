import SwiftUI

/// Compact "Suggested next set" hint shown above the new-set composer in
/// `ExerciseDetailView`. Tapping "Apply" updates the parent's input fields
/// to match the suggestion. Own struct to keep `ExerciseDetailView`'s
/// already-large body type-checkable.
struct SuggestedSetPill: View {
    let suggestion: SuggestedSet
    @Environment(\.weightUnit) private var weightUnit
    /// Called when the user taps "Apply". Caller updates the new-set inputs.
    let onApply: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(accentColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(suggestion.label.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(accentColor)
                    Text(headline)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }
                // RPE-coached suggestions justify themselves with a one-line
                // reason; surface it inline so the user sees the why, not
                // just the what. Other sources keep the previous compact look.
                if suggestion.source == .rpeCoach {
                    Text(suggestion.reasoning)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Button(action: onApply) {
                Text("Apply")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(accentColor.opacity(0.18), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Style

    private var headline: String {
        let w = weightUnit.format(suggestion.weight)
        return "\(suggestion.reps) reps · \(w)"
    }

    private var icon: String {
        switch suggestion.source {
        case .progression where suggestion.label.contains("rep"):
            return "arrow.up.right.circle.fill"
        case .progression: return "arrow.up.circle.fill"
        case .deload:      return "arrow.down.circle.fill"
        case .rpeCoach:    return rpeCoachIcon
        default:           return "arrow.clockwise.circle.fill"
        }
    }

    private var accentColor: Color {
        switch suggestion.source {
        case .progression: return .green
        case .deload:      return .orange
        case .rpeCoach:    return rpeCoachColor
        default:           return .blue
        }
    }

    /// RPE-coached suggestions span the full spectrum from "push harder"
    /// (green up arrow) through "match it" (blue) to "back off" (orange down
    /// arrow). We sniff the label for direction so the engine doesn't need a
    /// separate direction enum just for pill styling.
    private var rpeCoachIcon: String {
        let l = suggestion.label
        if l.contains("Add weight") { return "arrow.up.circle.fill" }
        if l.contains("Push") || l.contains("rep") { return "arrow.up.right.circle.fill" }
        if l.contains("Drop") { return "arrow.down.right.circle.fill" }
        if l.contains("Call it") || l.contains("Last hard") { return "checkmark.seal.fill" }
        return "equal.circle.fill"   // "Match it"
    }

    private var rpeCoachColor: Color {
        let l = suggestion.label
        if l.contains("Add weight") || l.contains("Push") { return .green }
        if l.contains("Drop") || l.contains("Last hard") || l.contains("Call it") { return .orange }
        return .blue   // "Match it"
    }
}
