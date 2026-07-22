import SwiftUI

/// The verdict banner that anchors the redesigned Home — date, intensity pill,
/// the two-line headline, the 4-up signal strip, and one line of caveat.
///
/// The whole card is one accent: border, corner wash, pill and the headline's
/// second line all take the color of today's intensity. That's the point of the
/// screen — you should be able to tell what kind of day it is from across the
/// room, before reading a word.
struct TodayHero: View {
    let plan: TodayPlan
    let signals: MicroSignalRow.Signals
    /// One-line qualifier under the signals — the thing the plan is working
    /// around today, e.g. "Triceps overworked this week — pushdown flagged".
    let caveat: String?
    /// Tone for the caveat's leading dot.
    var caveatColor: Color = AppTheme.Dark.Signal.caution
    /// True until the user has finished anything. The plan engine still names a
    /// session, but coaching someone to "hold the line" before they have a line
    /// is nonsense — day one gets its own verdict.
    var isFirstSession: Bool = false
    var onTap: () -> Void = {}

    private var accent: Color { AppTheme.Dark.accent(for: plan.intensity) }

    /// True when the engine recommended something other than what was on the
    /// calendar. The plan is *swapped*, never grayed out — a strained day still
    /// gets a session, just a different one.
    private var isSwapped: Bool {
        guard let scheduled = plan.scheduledName, !scheduled.isEmpty else { return false }
        return scheduled.localizedCaseInsensitiveCompare(plan.recommendedName) != .orderedSame
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 14) {
                topRow
                verdict
                MicroSignalRow(signals: signals)
                if let caveat, !caveat.isEmpty {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(caveatColor)
                            .frame(width: 4, height: 4)
                        Text(caveat)
                            .font(.system(size: 11.5))
                            .foregroundStyle(AppTheme.Dark.text2)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.Dark.surface)
            .background(wash)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Dark.Radius.hero, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Dark.Radius.hero, style: .continuous)
                    .strokeBorder(accent.opacity(0.33), lineWidth: 1)
            )
        }
        .buttonStyle(.pressableCard)
        .accessibilityElement(children: .contain)
        .accessibilityHint("Opens today's plan in detail")
    }

    /// Soft accent bloom out of the top-left corner. Sits behind the content so
    /// the card feels lit from one direction rather than uniformly tinted.
    private var wash: some View {
        RadialGradient(
            colors: [accent.opacity(0.18), .clear],
            center: .topLeading,
            startRadius: 0,
            endRadius: 240
        )
    }

    // MARK: - Top row

    private var topRow: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(Date.now, format: .dateTime.day())
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .tracking(-0.8)
                .foregroundStyle(AppTheme.Dark.text)
            VStack(alignment: .leading, spacing: 0) {
                Text(Date.now.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(AppTheme.Dark.text3)
                Text(Date.now.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(AppTheme.Dark.text2)
            }
            Spacer()
            pill
        }
        .accessibilityElement(children: .combine)
    }

    private var pill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(accent)
                .frame(width: 5, height: 5)
                .signalGlow(accent, radius: 4)
            Text(pillText)
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(accent)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(accent.opacity(0.13), in: Capsule())
        .overlay(Capsule().strokeBorder(accent.opacity(0.33), lineWidth: 1))
        .accessibilityLabel(pillAccessibilityLabel)
    }

    private var pillText: String {
        // A planned rest day isn't a low-confidence call, it's the plan — so it
        // says PLANNED rather than quoting a confidence level at the user.
        guard plan.intensity != .rest else { return "REST · PLANNED" }
        let confidence: String
        switch plan.confidence {
        case .low:    confidence = "LO"
        case .medium: confidence = "MED"
        case .high:   confidence = "HI"
        }
        return "\(plan.intensity.label.uppercased()) · \(confidence) CONF"
    }

    private var pillAccessibilityLabel: String {
        plan.intensity == .rest
            ? "Planned rest day"
            : "\(plan.intensity.label) intensity, \(plan.confidence.label)"
    }

    // MARK: - Verdict

    private var verdict: some View {
        let copy = verdictCopy
        return VStack(alignment: .leading, spacing: 0) {
            Text(copy.0)
                .foregroundStyle(AppTheme.Dark.text)
            Text(copy.1)
                .foregroundStyle(accent)
        }
        .font(.system(size: 32, weight: .bold, design: .rounded))
        .tracking(-1.4)
        .lineSpacing(0)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(copy.0) \(copy.1)")
    }

    /// Coach voice, two lines: the subject in white, the call in the accent.
    /// Never guilt-trips — a strained day is "pull back", not "you overdid it".
    ///
    /// TODO(step 12): move this and the nudge/finish strings into one copy table
    /// so the whole coach voice can be tone-reviewed in a single place.
    private var verdictCopy: (String, String) {
        if isFirstSession {
            return ("Day one.", "Let's get a baseline.")
        }
        switch plan.intensity {
        case .rest:
            return ("Rest today,", "let it rebuild.")
        case .light where isSwapped:
            return ("Pull back,", "deload today.")
        case .light:
            return ("\(plan.recommendedName),", "back it off ~20%.")
        case .moderate:
            return ("\(plan.recommendedName),", "hold the line.")
        case .hard:
            return ("\(plan.recommendedName),", "cleared for full.")
        }
    }
}

#Preview {
    TodayHero(
        plan: TodayPlan(
            scheduledName: "Push Day",
            recommendedName: "Push Day",
            intensity: .hard,
            reasons: [],
            adjustments: [],
            confidence: .high,
            alreadyTrainedToday: false,
            goEasyOnGroups: [],
            avoidGroups: [.triceps],
            generatedAt: .now
        ),
        signals: .init(
            hrv: .init(label: "HRV", value: "78", unit: "ms", delta: "+13",
                       color: AppTheme.Dark.Signal.recovery, accessibilityLabel: "HRV 78 milliseconds"),
            rhr: .init(label: "RHR", value: "54", unit: "bpm", delta: "−2",
                       color: AppTheme.Dark.Signal.recovery, accessibilityLabel: "Resting heart rate 54"),
            sleep: .init(label: "SLEEP", value: "7h 42m", unit: "", delta: "+32m",
                         color: AppTheme.Dark.Signal.recovery, accessibilityLabel: "Slept 7 hours 42 minutes"),
            strain: .init(label: "STRAIN", value: "14.2", unit: "k·kg", delta: "+1.6",
                          color: AppTheme.Dark.Signal.caution, accessibilityLabel: "Strain 14.2 thousand kilograms")
        ),
        caveat: "Triceps overworked this week — pushdown finisher flagged"
    )
    .padding(12)
    .background(AppTheme.Dark.bg)
    .preferredColorScheme(.dark)
}
