import SwiftUI

/// Compact banner shown at the top of the live workout view summarising
/// today's plan adjustments — e.g. "Reduce volume by ~1 set". Dismissible
/// per session.
struct TodayPlanAdjustmentsBanner: View {
    let plan: TodayPlan
    let onDismiss: () -> Void
    /// Optional preview + apply hook. When supplied, an "Apply" button
    /// appears alongside Dismiss and a confirmation alert is shown
    /// before any mutation. Caller performs the actual edit.
    var applyPreview: TodayPlanApply.Preview? = nil
    var onApply: (() -> Void)? = nil

    @State private var showingApplyConfirm = false

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
                .accessibilityLabel("Dismiss")
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

            // Apply CTA — only renders when caller supplied an apply
            // hook AND there's something concrete to do (preview is
            // non-empty). Avoids a "tap, nothing happens" footgun.
            if let preview = applyPreview, !preview.isEmpty, onApply != nil {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showingApplyConfirm = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Apply to this workout")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(intensityColor, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
                .confirmationDialog(
                    "Apply today's adjustments?",
                    isPresented: $showingApplyConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Apply") {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        onApply?()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text(preview.summary + " Logged sets won't be touched.")
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
