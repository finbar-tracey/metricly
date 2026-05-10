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
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.16))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accentColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.label)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accentColor)
                Text(headline)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                Text(suggestion.reasoning)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button("Apply", action: onApply)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(accentColor, in: Capsule())
                .buttonStyle(.plain)
        }
        .padding(12)
        .background(accentColor.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(accentColor.opacity(0.25), lineWidth: 1)
        )
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
        default:           return "arrow.clockwise.circle.fill"
        }
    }

    private var accentColor: Color {
        switch suggestion.source {
        case .progression: return .green
        case .deload:      return .orange
        default:           return .blue
        }
    }
}
