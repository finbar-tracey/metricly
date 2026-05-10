import SwiftUI

// MARK: - WatchActiveMetricsView
//
// Big-numbers screen the user pushes from the HR banner mid-workout.
// Five glanceable values: heart rate, active calories, elapsed time,
// working set count, and total volume. No chrome, no chart — this is
// for "what's my number right now" reads between sets.

struct WatchActiveMetricsView: View {
    @EnvironmentObject private var sessionManager: WatchWorkoutSessionManager
    let exercises: [WatchExerciseRecord]
    let useKg: Bool

    private var workingSets: [WatchSetRecord] {
        exercises.flatMap(\.sets).filter { !$0.isWarmUp }
    }

    private var totalVolumeKg: Double {
        workingSets.reduce(0) { $0 + Double($1.reps) * $1.weightKg }
    }

    private var formattedVolume: String {
        let display = useKg ? totalVolumeKg : totalVolumeKg * 2.20462
        if display >= 10_000 {
            return String(format: "%.1fk", display / 1000) + (useKg ? " kg" : " lb")
        }
        let rounded = String(format: "%.0f", display)
        return "\(rounded) \(useKg ? "kg" : "lb")"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                // Heart rate — primary, biggest type, zone-tinted
                heartRow
                divider
                // Time + calories side by side
                pairRow(
                    leadingLabel: "TIME",
                    leadingValue: formatDuration(sessionManager.elapsedSeconds),
                    leadingTint: .yellow,
                    trailingLabel: "ACT KCAL",
                    trailingValue: "\(Int(sessionManager.activeCalories))",
                    trailingTint: .orange
                )
                divider
                // Sets + volume
                pairRow(
                    leadingLabel: "SETS",
                    leadingValue: "\(workingSets.count)",
                    leadingTint: .green,
                    trailingLabel: "VOLUME",
                    trailingValue: workingSets.isEmpty ? "—" : formattedVolume,
                    trailingTint: .blue
                )
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)
        }
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(summaryAccessibilityLabel)
    }

    // MARK: - Rows

    private var heartRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "heart.fill")
                .font(.title3)
                .foregroundStyle(.red)
                .symbolEffect(.pulse.byLayer, options: .repeating, isActive: sessionManager.heartRate > 0)
            if sessionManager.heartRate > 0 {
                Text("\(Int(sessionManager.heartRate))")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(.red)
                    .monospacedDigit()
                Text("BPM")
                    .font(.caption2.bold())
                    .foregroundStyle(.red.opacity(0.75))
            } else {
                Text("—")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(.red.opacity(0.4))
            }
            Spacer(minLength: 0)
        }
    }

    private func pairRow(leadingLabel: String, leadingValue: String, leadingTint: Color,
                         trailingLabel: String, trailingValue: String, trailingTint: Color) -> some View {
        HStack(spacing: 6) {
            statTile(label: leadingLabel, value: leadingValue, tint: leadingTint)
            statTile(label: trailingLabel, value: trailingValue, tint: trailingTint)
        }
    }

    private func statTile(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private var divider: some View {
        Color.clear.frame(height: 2)
    }

    // MARK: - Accessibility

    private var summaryAccessibilityLabel: String {
        var parts: [String] = []
        if sessionManager.heartRate > 0 {
            parts.append("\(Int(sessionManager.heartRate)) BPM")
        }
        parts.append(formatDuration(sessionManager.elapsedSeconds))
        parts.append("\(Int(sessionManager.activeCalories)) active calories")
        let n = workingSets.count
        parts.append("\(n) \(n == 1 ? "set" : "sets")")
        if !workingSets.isEmpty { parts.append("\(formattedVolume) total volume") }
        return parts.joined(separator: ", ")
    }
}
