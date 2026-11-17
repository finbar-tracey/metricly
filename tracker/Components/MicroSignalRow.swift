import SwiftUI

/// The 4-up signal strip inside `TodayHero` — HRV, resting HR, sleep, strain.
///
/// Deliberately dumb: it renders whatever cells it's handed. The decision about
/// *which* number is good news lives with the caller, because "RHR down 2 bpm"
/// is a recovery signal while "strain up 1.6k" is a caution one, and only the
/// caller knows the baselines.
struct MicroSignalRow: View {
    struct Cell {
        let label: String
        let value: String
        let unit: String
        /// Signed change vs baseline, pre-formatted ("+13", "−2", "—").
        let delta: String
        /// Tone for the delta line, from `AppTheme.Dark.Signal`.
        let color: Color
        /// Spoken form for VoiceOver — the visual is abbreviated past the point
        /// of being readable aloud ("HRV 78 ms" beats "H R V 78 m s").
        let accessibilityLabel: String
    }

    struct Signals {
        let hrv: Cell
        let rhr: Cell
        let sleep: Cell
        let strain: Cell
        var cells: [Cell] { [hrv, rhr, sleep, strain] }
    }

    let signals: Signals

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            // Four cramped columns can't hold accessibility-size text; stack them.
            VStack(spacing: 8) {
                ForEach(signals.cells, id: \.label) { cell in
                    self.cell(cell)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 10)
            .darkWell()
        } else {
            strip
        }
    }

    private var strip: some View {
        HStack(spacing: 0) {
            ForEach(Array(signals.cells.enumerated()), id: \.element.label) { index, cell in
                self.cell(cell)
                if index < signals.cells.count - 1 {
                    Rectangle()
                        .fill(AppTheme.Dark.hairline)
                        .frame(width: 0.5)
                        .padding(.vertical, 4)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 10)
        .darkWell()
    }

    private func cell(_ cell: Cell) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(cell.label)
                .scaledFont(size: 8.5, weight: .bold, design: .monospaced)
                .tracking(1)
                .foregroundStyle(AppTheme.Dark.text4)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(cell.value)
                    .scaledFont(size: 16, weight: .bold, design: .rounded)
                    .tracking(-0.5)
                    .foregroundStyle(AppTheme.Dark.text)
                    .monospacedDigit()
                Text(cell.unit)
                    .scaledFont(size: 8.5, design: .monospaced)
                    .foregroundStyle(AppTheme.Dark.text3)
            }
            Text(cell.delta)
                .scaledFont(size: 9, weight: .semibold, design: .monospaced)
                .foregroundStyle(cell.color)
        }
        .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cell.accessibilityLabel)
    }
}

#Preview {
    MicroSignalRow(
        signals: .init(
            hrv: .init(label: "HRV", value: "78", unit: "ms", delta: "+13",
                       color: AppTheme.Dark.Signal.recovery,
                       accessibilityLabel: "Heart rate variability 78 milliseconds, 13 above baseline"),
            rhr: .init(label: "RHR", value: "54", unit: "bpm", delta: "−2",
                       color: AppTheme.Dark.Signal.recovery,
                       accessibilityLabel: "Resting heart rate 54 beats per minute, 2 below baseline"),
            sleep: .init(label: "SLEEP", value: "7h 42m", unit: "", delta: "+32m",
                         color: AppTheme.Dark.Signal.recovery,
                         accessibilityLabel: "Slept 7 hours 42 minutes, 32 minutes above baseline"),
            strain: .init(label: "STRAIN", value: "14.2", unit: "k·kg", delta: "+1.6",
                          color: AppTheme.Dark.Signal.caution,
                          accessibilityLabel: "7-day training strain 14.2 thousand kilograms, 1.6 above baseline")
        )
    )
    .padding()
    .background(AppTheme.Dark.bg)
    .preferredColorScheme(.dark)
}
