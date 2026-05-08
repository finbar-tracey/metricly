import SwiftUI

/// Compact banner shown at the top of the live workout view summarising
/// today's plan adjustments — e.g. "Reduce volume by ~1 set". Dismissible
/// per session.
struct TodayPlanAdjustmentsBanner: View {
    let plan: TodayPlan
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(intensityColor.opacity(0.16))
                        .frame(width: 30, height: 30)
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(intensityColor)
                }
                Text("Today's plan: \(plan.intensity.label)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(plan.adjustments, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 4))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 6)
                        Text(tip)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(14)
        .background(intensityColor.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: AppTheme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                .strokeBorder(intensityColor.opacity(0.25), lineWidth: 1)
        )
    }

    private var intensityColor: Color {
        switch plan.intensity {
        case .rest:     return .gray
        case .light:    return .teal
        case .moderate: return .blue
        case .hard:     return .orange
        }
    }
}
