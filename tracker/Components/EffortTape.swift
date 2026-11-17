import SwiftUI

/// The lead instrument on the redesigned Home: a 14-day + today strip where
/// each column is one day and the bar height is that day's training volume.
///
/// Reading it should take under a second — the shape of the fortnight first,
/// the individual days only if you look. So: lift days carry the signal color
/// for how hard they were, cardio is a fixed shorter calm bar (a cardio session
/// has no comparable volume number, and faking one would make the strip lie),
/// rest is a thin baseline, and today is hollow-bordered in the day's accent
/// because it hasn't happened yet.
struct EffortTape: View {
    struct Day: Identifiable {
        /// One entry per calendar day, so identity survives data rebuilds.
        var id: Date { date }
        /// Single-letter weekday initial.
        let letter: String
        let kind: Kind
        /// Lifting volume in *thousands* of kg. 0 for rest, cardio and today.
        let volumeK: Double
        /// Session RPE, shown as a pip above the bar. nil for rest and today.
        let rpe: Double?
        let date: Date
        /// The workout to open when this column is tapped, if there is one.
        let workout: Workout?

        enum Kind { case rest, light, moderate, hard, cardio, today }
    }

    let days: [Day]
    /// Trailing-window totals for the header's right-hand readout.
    var totalVolumeK: Double = 0
    var sessionCount: Int = 0
    /// Today's accent — the tape is the one place on Home that shows the
    /// fortnight, so today's cell has to agree with the hero below it.
    var accent: Color = AppTheme.Dark.Signal.recovery
    var onSelectDay: (Workout) -> Void = { _ in }

    @Environment(\.weightUnit) private var weightUnit

    /// Nominal cell width from the handoff. Columns are flexible and the bar is
    /// capped at this, so the strip stays centred on a Pro Max and compresses
    /// rather than clipping on an SE.
    private let cellW: CGFloat = 18
    private let gap: CGFloat = 4
    private let fullH: CGFloat = 72
    private let pipH: CGFloat = 13

    private var maxVolumeK: Double {
        max(0.01, days.map(\.volumeK).max() ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            HStack(alignment: .bottom, spacing: gap) {
                ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                    interactiveColumn(day, index: index)
                }
            }
            dayLetters
            legend
        }
        .padding(.horizontal, 16)
        // Fixed-height columns can't grow with the text; past this size the
        // letters and pips would collide.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    // MARK: - Header

    /// `totalVolumeK` arrives as thousands of kg; show it in the user's unit.
    private var displayVolumeK: Double { weightUnit.display(totalVolumeK * 1000) / 1000 }

    private func volumeText(_ volumeK: Double) -> String {
        volumeK.formatted(.number.precision(.fractionLength(1)))
    }

    private var header: some View {
        let title = Text("14 DAYS · TRAINING EFFORT")
            .scaledFont(size: 10, weight: .semibold, design: .monospaced)
            .tracking(1.4)
            .foregroundStyle(AppTheme.Dark.text3)
        let totals = Text("\(volumeText(displayVolumeK))k \(weightUnit.label) · \(sessionCount) sessions")
            .scaledFont(size: 10, weight: .semibold, design: .monospaced)
            .tracking(0.6)
            .foregroundStyle(AppTheme.Dark.text3)
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                title
                Spacer()
                totals
            }
            VStack(alignment: .leading, spacing: 2) {
                title
                totals
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Last 14 days: \(volumeText(displayVolumeK)) thousand \(weightUnit.label) across \(sessionCount) sessions"
        )
    }

    // MARK: - Columns

    @ViewBuilder
    private func column(_ day: Day, index: Int) -> some View {
        let isToday = day.kind == .today

        VStack(spacing: 2) {
            pip(for: day)
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: AppTheme.Dark.Radius.bar, style: .continuous)
                .fill(fill(for: day))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Dark.Radius.bar, style: .continuous)
                        .strokeBorder(isToday ? AppTheme.Dark.text : .clear, lineWidth: 1)
                )
                .frame(maxWidth: cellW)
                .frame(height: height(for: day))
                .opacity(day.kind == .rest ? 0.55 : 0.92)
                .signalGlow(isToday ? accent : .clear, radius: 12)
                .growIn(delay: Double(index) * AppTheme.Dark.Motion.tapeStagger)
        }
        .frame(maxWidth: .infinity)
        .frame(height: fullH + pipH + 2, alignment: .bottom)
        .contentShape(Rectangle())
    }

    /// Columns with a workout are real buttons; the rest are static, so
    /// VoiceOver doesn't announce dead "dimmed" controls.
    @ViewBuilder
    private func interactiveColumn(_ day: Day, index: Int) -> some View {
        if let workout = day.workout {
            Button { onSelectDay(workout) } label: { column(day, index: index) }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityLabel(for: day))
                .accessibilityHint("Opens this workout")
        } else {
            column(day, index: index)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel(for: day))
        }
    }

    @ViewBuilder
    private func pip(for day: Day) -> some View {
        switch day.kind {
        case .today:
            Text("NOW")
                .scaledFont(size: 7.5, weight: .bold, design: .monospaced)
                .tracking(0.6)
                .foregroundStyle(AppTheme.Dark.text)
        default:
            if let rpe = day.rpe {
                Text(rpe, format: .number.precision(.fractionLength(1)))
                    .scaledFont(size: 7.5, weight: .semibold, design: .monospaced)
                    .foregroundStyle(AppTheme.Dark.text4)
            } else {
                Color.clear.frame(height: pipH)
            }
        }
    }

    private func height(for day: Day) -> CGFloat {
        switch day.kind {
        case .rest:   return 3
        // Cardio has no volume to scale, so it gets a constant mid-height bar —
        // present in the shape of the fortnight without pretending to a number.
        case .cardio: return max(14, fullH * 0.35)
        case .today:  return fullH * 0.55
        default:      return max(8, CGFloat(day.volumeK / maxVolumeK) * fullH)
        }
    }

    private func fill(for day: Day) -> LinearGradient {
        let color = day.kind == .today ? accent : color(for: day.kind)
        return LinearGradient(
            colors: [color, color.opacity(0.9)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func color(for kind: Day.Kind) -> Color {
        switch kind {
        case .hard, .today: return AppTheme.Dark.Signal.recovery
        case .moderate:     return AppTheme.Dark.Signal.caution
        case .light:        return AppTheme.Dark.Signal.focus
        case .cardio:       return AppTheme.Dark.Signal.calm
        case .rest:         return AppTheme.Dark.tapeRest
        }
    }

    private var dayLetters: some View {
        HStack(spacing: gap) {
            ForEach(days) { day in
                Text(day.letter)
                    .scaledFont(size: 8, weight: .semibold, design: .monospaced)
                    .tracking(0.4)
                    .foregroundStyle(day.kind == .today ? AppTheme.Dark.text : AppTheme.Dark.text4)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Legend

    private var legend: some View {
        HStack(spacing: 12) {
            swatch("HARD", AppTheme.Dark.Signal.recovery)
            swatch("MOD", AppTheme.Dark.Signal.caution)
            swatch("LIGHT", AppTheme.Dark.Signal.focus)
            swatch("CARDIO", AppTheme.Dark.Signal.calm)
            swatch("REST", AppTheme.Dark.tapeRest)
        }
        .padding(.top, 2)
        .accessibilityHidden(true)
    }

    private func swatch(_ label: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .scaledFont(size: 8.5, weight: .semibold, design: .monospaced)
                .tracking(0.6)
                .foregroundStyle(AppTheme.Dark.text3)
        }
    }

    // MARK: - Accessibility

    private func accessibilityLabel(for day: Day) -> String {
        let when = day.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        switch day.kind {
        case .today:  return "Today, \(when). Not trained yet."
        case .rest:   return "\(when). Rest day."
        case .cardio: return "\(when). Cardio session."
        default:
            let volume = volumeText(weightUnit.display(day.volumeK * 1000) / 1000)
            let effort = day.rpe.map { ", RPE \($0.formatted(.number.precision(.fractionLength(1))))" } ?? ""
            let level: String
            switch day.kind {
            case .hard:     level = String(localized: "Hard day")
            case .moderate: level = String(localized: "Moderate day")
            default:        level = String(localized: "Light day")
            }
            return "\(when). \(level). \(volume) thousand \(weightUnit.label)\(effort)."
        }
    }
}

#Preview {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    let kinds: [EffortTape.Day.Kind] = [
        .rest, .hard, .cardio, .moderate, .rest, .hard, .light,
        .moderate, .rest, .cardio, .hard, .rest, .moderate, .rest, .today
    ]
    let volumes: [Double] = [0, 13.4, 0, 10.8, 0, 14.2, 5.2, 11.2, 0, 0, 14.8, 0, 12.8, 0, 0]

    return EffortTape(
        days: kinds.indices.map { index in
            let date = calendar.date(byAdding: .day, value: index - 14, to: today) ?? today
            return .init(
                letter: String(date.formatted(.dateTime.weekday(.narrow))),
                kind: kinds[index],
                volumeK: volumes[index],
                rpe: volumes[index] > 0 ? 7.4 : nil,
                date: date,
                workout: nil
            )
        },
        totalVolumeK: 74.4,
        sessionCount: 11
    )
    .padding(.vertical, 24)
    .background(AppTheme.Dark.bg)
    .preferredColorScheme(.dark)
}
