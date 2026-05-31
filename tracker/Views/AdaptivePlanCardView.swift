import SwiftUI

/// Renders the "Today" recovery-aware recommendation card produced by
/// `TodayPlanEngine`. Lives in its own struct so `HomeDashboardView.body` doesn't
/// have to type-check the whole layout in a single opaque-return chain.
struct AdaptivePlanCardView: View {
    let plan: TodayPlan
    let onStart: () -> Void
    let onTapDetail: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            headline
            if !plan.reasons.isEmpty { reasonsList }
            if !plan.adjustments.isEmpty { adjustmentsBox }
            footer
        }
        .appCard()
        // Card-wide tap goes to detail. The Start button has its own Button
        // action and stops the tap from bubbling.
        .contentShape(Rectangle())
        .onTapGesture { onTapDetail() }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 8) {
            Text("Today")
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Spacer()
            intensityPill
        }
    }

    private var headline: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [intensityColor.opacity(0.28), intensityColor.opacity(0.12)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 46, height: 46)
                    .overlay(Circle().stroke(intensityColor.opacity(0.30), lineWidth: 0.5))
                    .shadow(color: intensityColor.opacity(0.25), radius: 6, y: 3)
                Image(systemName: intensityIcon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(intensityColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.recommendedName)
                    .font(.headline.weight(.bold))
                    .lineLimit(2)
                headlineSubtitle
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var headlineSubtitle: some View {
        if plan.alreadyTrainedToday {
            Text("Workout complete")
                .font(.caption).foregroundStyle(.green)
        } else if let scheduled = plan.scheduledName, scheduled != plan.recommendedName {
            Text("(scheduled: \(scheduled))")
                .font(.caption).foregroundStyle(.secondary)
        } else {
            EmptyView()
        }
    }

    private var reasonsList: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(plan.reasons, id: \.self) { reason in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 4))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 6)
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var adjustmentsBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Adjustments")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
            ForEach(plan.adjustments, id: \.self) { tip in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(intensityColor)
                        .padding(.top, 2)
                    Text(tip)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(10)
        .padding(.leading, 4)
        .background(intensityColor.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(intensityColor.opacity(0.55))
                .frame(width: 3)
                .padding(.vertical, 8)
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            confidenceBadge
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
            Spacer()
            startButton
        }
    }

    @ViewBuilder
    private var startButton: some View {
        if !plan.alreadyTrainedToday && plan.intensity != .rest {
            Button(action: onStart) {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Start")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18).padding(.vertical, 9)
                .background(
                    LinearGradient(
                        colors: [intensityColor, intensityColor.opacity(0.8)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    in: Capsule()
                )
                .shadow(color: intensityColor.opacity(0.45), radius: 8, y: 4)
            }
            .buttonStyle(.pressableCard)
        } else {
            EmptyView()
        }
    }

    // MARK: - Style helpers

    private var intensityColor: Color {
        switch plan.intensity {
        case .rest:     return .gray
        case .light:    return .teal
        case .moderate: return .blue
        case .hard:     return .orange
        }
    }

    private var intensityIcon: String {
        switch plan.intensity {
        case .rest:     return "moon.stars.fill"
        case .light:    return "leaf.fill"
        case .moderate: return "dumbbell.fill"
        case .hard:     return "flame.fill"
        }
    }

    private var intensityPill: some View {
        HStack(spacing: 4) {
            Image(systemName: intensityIcon)
                .font(.system(size: 9, weight: .bold))
            Text(plan.intensity.label.uppercased())
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(intensityColor)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .gradientCapsule(intensityColor)
    }

    private var confidenceBadge: some View {
        let icon: String
        let color: Color
        switch plan.confidence {
        case .low:    icon = "questionmark.circle";       color = .secondary
        case .medium: icon = "circle.lefthalf.filled";    color = .secondary
        case .high:   icon = "checkmark.circle.fill";     color = .green
        }
        return HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10))
            Text(plan.confidence.label)
                .font(.caption2.weight(.medium))
        }
        .foregroundStyle(color)
    }
}
