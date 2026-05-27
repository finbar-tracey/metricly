import SwiftUI

/// Suggested-bedtime card shown on the home dashboard when there's
/// still active caffeine in the system. Read-only; taps deep-link to
/// the caffeine tracker.
struct HomeBedtimeSuggestion: View {
    let bedtime: Date
    let delayedByCaffeine: Bool
    let clearTime: Date?

    var body: some View {
        let color: Color = delayedByCaffeine ? .orange : .indigo

        return NavigationLink { CaffeineTrackerView() } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.72)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .shadow(color: color.opacity(0.45), radius: 9, x: 0, y: 4)
                    Image(systemName: delayedByCaffeine ? "moon.fill" : "moon.zzz.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Suggested Bedtime")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    HStack(spacing: 6) {
                        Text(bedtime, format: .dateTime.hour().minute())
                            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        if delayedByCaffeine {
                            Text("· Caffeine still active").font(.caption).foregroundStyle(.orange)
                        }
                    }
                }
                Spacer()
                if let clearTime {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Clear by")
                            .font(.system(.caption2, design: .rounded).weight(.bold))
                            .foregroundStyle(.tertiary)
                            .tracking(0.3)
                            .textCase(.uppercase)
                        Text(clearTime, format: .dateTime.hour().minute())
                            .font(.caption.bold().monospacedDigit()).foregroundStyle(.brown)
                    }
                }
                Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.10), radius: 16, x: 0, y: 5)
        }
        .buttonStyle(.pressableCard)
    }
}
