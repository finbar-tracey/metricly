import SwiftUI

/// Small inline callout shown at the top of `ExerciseDetailView` when
/// today's plan has guidance specific to this exercise's muscle group.
struct ExercisePlanHintView: View {
    enum Tone {
        case info, caution, warning

        var color: Color {
            switch self {
            case .info:    return .blue
            case .caution: return .teal
            case .warning: return .orange
            }
        }
    }

    let tone: Tone
    let icon: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tone.color)
                .padding(.top, 1)
            Text(message)
                .font(.caption)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(tone.color.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: AppTheme.chipRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.chipRadius)
                .strokeBorder(tone.color.opacity(0.25), lineWidth: 1)
        )
    }
}
