import SwiftUI

/// The post-workout payoff (design_handoff_app, screen-finish.jsx) — shown once
/// the finish sheet commits the session. Restrained celebration: a check ring
/// draws in, stats count up, one highlight line, the recovery cost, and a look
/// at tomorrow.
///
/// Additive: it doesn't collect anything (the finish sheet already took rating,
/// feel, soreness) and touches no data — it reads the saved workout and shows
/// the payoff. Praises a deload as readily as a PR; never guilt-trips.
struct SessionSummaryView: View {
    let data: SessionSummaryData
    /// "See the trend" — ends the finish flow. Wires to the Trends tab in
    /// step 11; for now it returns to Home, where the effort tape *is* the trend.
    var onSeeTrend: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 0) {
                    CheckRing(accent: data.accent)
                        .padding(.top, 30)
                        .padding(.bottom, 20)
                    verdict
                    stats
                    highlight
                    bulletLines
                }
                .padding(.bottom, 20)
            }
            cta
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.Dark.bg.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
    }

    private var header: some View {
        HStack {
            Text("SESSION COMPLETE")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(AppTheme.Dark.text3)
            Spacer()
            Text(data.dateText)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(AppTheme.Dark.text3)
            Button(action: onSeeTrend) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.Dark.text3)
                    .padding(.leading, 12)
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
    }

    private var verdict: some View {
        VStack(spacing: 0) {
            Text(data.verdictA)
                .foregroundStyle(AppTheme.Dark.text)
            Text(data.verdictB)
                .foregroundStyle(data.accent)
        }
        .font(.system(size: 32, weight: .bold, design: .rounded))
        .tracking(-1.4)
        .multilineTextAlignment(.center)
        .lineSpacing(0)
        .minimumScaleFactor(0.7)
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(data.verdictA) \(data.verdictB)")
    }

    private var stats: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
            spacing: 10
        ) {
            ForEach(data.stats) { stat in
                statTile(stat)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 24)
    }

    private func statTile(_ stat: SessionSummaryData.Stat) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(stat.label)
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(AppTheme.Dark.text4)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                CountUpNumber(target: stat.value, decimals: stat.decimals)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .tracking(-1)
                    .foregroundStyle(AppTheme.Dark.text)
                    .monospacedDigit()
                Text(stat.unit)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(AppTheme.Dark.text3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .darkCard(radius: 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stat.label): \(stat.spokenValue) \(stat.unit)")
    }

    private var highlight: some View {
        HStack(spacing: 10) {
            Image(systemName: "flame.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(data.accent)
            Text(data.highlight)
                .font(.system(size: 12.5))
                .foregroundStyle(AppTheme.Dark.text)
                .lineSpacing(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .darkCard(radius: 14, border: data.accent.opacity(0.3))
        .padding(.horizontal, 18)
        .padding(.top, 14)
    }

    @ViewBuilder
    private var bulletLines: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let cost = data.costLine {
                bullet(cost, dot: AppTheme.Dark.Signal.caution)
            }
            if let tomorrow = data.tomorrowLine {
                bullet(tomorrow, dot: AppTheme.Dark.text3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 14)
    }

    private func bullet(_ text: String, dot: Color) -> some View {
        HStack(spacing: 8) {
            Circle().fill(dot).frame(width: 4, height: 4)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.Dark.text2)
            Spacer(minLength: 0)
        }
    }

    private var cta: some View {
        Button(action: onSeeTrend) {
            HStack {
                Text("See the trend")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .tracking(-0.2)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(AppTheme.Dark.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(data.accent, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .signalGlow(data.accent, radius: 16, opacity: 0.4)
        }
        .buttonStyle(.pressableCard)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}

/// A number that counts up from zero to `target` on appear. Drives an
/// `AnimatableModifier` whose `animatableData` is the value, so SwiftUI rebuilds
/// the text at each interpolated step rather than snapping start→end. Reduce
/// Motion shows the final value at once.
private struct CountUpNumber: View {
    let target: Double
    let decimals: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        // The modifier replaces this placeholder with the interpolated number;
        // font/color set on `CountUpNumber` reach it through the environment.
        Text(verbatim: "")
            .modifier(CountingText(value: shown ? target : 0, decimals: decimals))
            .onAppear {
                guard !reduceMotion else { shown = true; return }
                withAnimation(.easeOut(duration: 0.8)) { shown = true }
            }
    }
}

private struct CountingText: AnimatableModifier {
    var value: Double
    let decimals: Int

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    func body(content: Content) -> some View {
        Text(value, format: .number.precision(.fractionLength(decimals)))
    }
}
