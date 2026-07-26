import SwiftUI

/// What a brand-new user sees on Trends before any session exists
/// (design_handoff_app, screen-history.jsx → EmptyHistory): "Day one.", a ghost
/// tape with today's cell lit, and the ladder of what each milestone unlocks.
///
/// Not a dead end — it teaches what the engine will learn and points at the one
/// action that starts it.
struct EmptyTrendsContent: View {
    /// Start the first workout. When nil (e.g. reached read-only), the CTA hides.
    var onStart: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            title
            ghostTape
            unlocks
            if onStart != nil {
                cta
            }
        }
        .padding(.bottom, 28)
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Day")
                    .foregroundStyle(AppTheme.Dark.text)
                Text("one.")
                    .foregroundStyle(AppTheme.Dark.Signal.recovery)
            }
            .font(.system(size: 30, weight: .bold, design: .rounded))
            .tracking(-1.2)
            Text("Log your first session and the engine starts learning you — baselines, load, readiness.")
                .font(.system(size: 12.5))
                .foregroundStyle(AppTheme.Dark.text3)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 18)
    }

    private var ghostTape: some View {
        section(title: "YOUR TAPE", right: "EMPTY — FOR NOW") {
            VStack(spacing: 6) {
                HStack(spacing: 5) {
                    ForEach(0..<14, id: \.self) { index in
                        let isToday = index == 13
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(
                                style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                            )
                            .foregroundStyle(isToday ? AppTheme.Dark.Signal.recovery : AppTheme.Dark.hairline)
                            .frame(height: 44)
                            .signalGlow(isToday ? AppTheme.Dark.Signal.recovery.opacity(0.4) : .clear, radius: 8)
                            .frame(maxWidth: .infinity)
                    }
                }
                Text("TODAY → FIRST BAR")
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(AppTheme.Dark.Signal.recovery)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .accessibilityElement()
            .accessibilityLabel("Your 14-day tape, empty until your first session")
        }
    }

    private var unlocks: some View {
        section(title: "WHAT UNLOCKS", right: nil) {
            VStack(spacing: 0) {
                unlockRow("3 sessions", "Readiness verdicts — train hard or pull back, daily", isLast: false)
                unlockRow("7 days", "Muscle-load map — what's fresh, what's fried", isLast: false)
                unlockRow("14 days", "Adaptive plans — weights picked for the day you're having", isLast: true)
            }
            .darkCard(radius: 16)
        }
    }

    private func unlockRow(_ when: String, _ what: String, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(when.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(AppTheme.Dark.Signal.recovery)
                .frame(width: 74, alignment: .leading)
            Text(what)
                .font(.system(size: 12.5))
                .foregroundStyle(AppTheme.Dark.text2)
                .lineSpacing(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(AppTheme.Dark.hairlineSoft).frame(height: 0.5).padding(.leading, 14)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("After \(when): \(what)")
    }

    private var cta: some View {
        Button { onStart?() } label: {
            HStack {
                Text("Start first workout")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .tracking(-0.2)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(AppTheme.Dark.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(AppTheme.Dark.Signal.recovery, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .signalGlow(AppTheme.Dark.Signal.recovery, radius: 16, opacity: 0.4)
        }
        .buttonStyle(.pressableCard)
        .padding(.horizontal, 16)
        .padding(.top, 22)
    }

    @ViewBuilder
    private func section<Content: View>(
        title: String,
        right: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(AppTheme.Dark.text3)
                Spacer()
                if let right {
                    Text(right)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(0.6)
                        .foregroundStyle(AppTheme.Dark.text4)
                }
            }
            content()
        }
        .padding(.horizontal, 18)
        .padding(.top, 24)
    }
}
