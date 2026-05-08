import SwiftUI

/// Detailed breakdown of the Today's Plan recommendation — what drove the
/// readiness score, which muscles are fatigued, and what the suggested
/// adjustments mean. Pushed when the user taps the Today card on Home.
struct TodayPlanDetailView: View {
    let plan: TodayPlan
    let recovery: RecoveryResult
    let health: HealthSignals

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.sectionSpacing) {
                readinessHero
                signalsCard
                if !recovery.muscleResults.isEmpty {
                    muscleFatigueCard
                }
                reasoningCard
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Today's Plan")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Readiness hero

    private var readinessHero: some View {
        let score = recovery.readinessScore
        let pct = Int(round(score * 100))
        let color = RecoveryEngine.freshnessColor(score)

        return VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 12)
                    .frame(width: 130, height: 130)
                Circle()
                    .trim(from: 0, to: max(0.001, score))
                    .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 130, height: 130)
                VStack(spacing: 2) {
                    Text("\(pct)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("READINESS")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            Text(RecoveryEngine.readinessLabel(score))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .appCard()
    }

    // MARK: - Signals card (sleep, HRV, resting HR)

    private var signalsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Health Signals", icon: "heart.text.square.fill", color: .pink)

            VStack(spacing: 0) {
                signalRow(
                    icon: "moon.fill",
                    color: .indigo,
                    label: "Sleep last night",
                    value: sleepValue,
                    delta: sleepDelta,
                    deltaTone: sleepTone
                )
                Divider().padding(.leading, 50)
                signalRow(
                    icon: "waveform.path.ecg",
                    color: .red,
                    label: "HRV vs baseline",
                    value: hrvValue,
                    delta: hrvDelta,
                    deltaTone: hrvTone
                )
                Divider().padding(.leading, 50)
                signalRow(
                    icon: "heart.fill",
                    color: .pink,
                    label: "Resting HR",
                    value: rhrValue,
                    delta: rhrDelta,
                    deltaTone: rhrTone
                )
            }
            .background(Color(.tertiarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 12))
        }
        .appCard()
    }

    private func signalRow(
        icon: String,
        color: Color,
        label: String,
        value: String,
        delta: String?,
        deltaTone: SignalTone
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.14))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.caption.weight(.medium))
                Text(value)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
            }
            Spacer()
            if let delta {
                Text(delta)
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(deltaTone.color)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(deltaTone.color.opacity(0.12), in: Capsule())
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    // MARK: - Muscle fatigue list

    private var muscleFatigueCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Muscle Fatigue", icon: "figure.strengthtraining.traditional", color: .orange)

            VStack(spacing: 10) {
                ForEach(recovery.muscleResults) { result in
                    HStack(spacing: 10) {
                        Text(result.group.rawValue)
                            .font(.caption.weight(.semibold))
                            .frame(width: 70, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.tertiarySystemFill))
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(RecoveryEngine.freshnessColor(result.freshness))
                                    .frame(width: max(4, geo.size.width * result.freshness))
                            }
                        }
                        .frame(height: 10)
                        Text(RecoveryEngine.freshnessLabel(result.freshness))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 80, alignment: .trailing)
                    }
                }
            }
        }
        .appCard()
    }

    // MARK: - Reasoning recap

    private var reasoningCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Why This Plan", icon: "lightbulb.fill", color: .yellow)

            VStack(alignment: .leading, spacing: 12) {
                Text(plan.recommendedName)
                    .font(.headline.weight(.bold))
                if !plan.reasons.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(plan.reasons, id: \.self) { r in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 4))
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 6)
                                Text(r).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                if !plan.adjustments.isEmpty {
                    Divider().padding(.vertical, 4)
                    Text("Suggested adjustments")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(plan.adjustments, id: \.self) { a in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.orange)
                                    .padding(.top, 2)
                                Text(a).font(.caption).foregroundStyle(.primary)
                            }
                        }
                    }
                }
                Divider().padding(.vertical, 4)
                HStack(spacing: 6) {
                    Image(systemName: confidenceIcon).font(.caption).foregroundStyle(.secondary)
                    Text(plan.confidence.label).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .appCard()
    }

    // MARK: - Derived signal values

    private enum SignalTone {
        case good, neutral, bad

        var color: Color {
            switch self {
            case .good:    return .green
            case .neutral: return .secondary
            case .bad:     return .orange
            }
        }
    }

    private var sleepValue: String {
        guard let m = health.sleepMinutes, m > 0 else { return "—" }
        let h = m / 60
        return String(format: "%.1fh", h)
    }
    private var sleepDelta: String? {
        guard let m = health.sleepMinutes, m > 0 else { return nil }
        let h = m / 60
        if h < 6 { return "Short" }
        if h >= 7.5 { return "Good" }
        return nil
    }
    private var sleepTone: SignalTone {
        guard let m = health.sleepMinutes, m > 0 else { return .neutral }
        let h = m / 60
        if h < 6 { return .bad }
        if h >= 7.5 { return .good }
        return .neutral
    }

    private var hrvValue: String {
        guard let v = health.todayHRV else { return "—" }
        return String(format: "%.0f ms", v)
    }
    private var hrvDelta: String? {
        guard let v = health.todayHRV, let avg = health.averageHRV, avg > 0 else { return nil }
        let pct = (v - avg) / avg * 100
        if abs(pct) < 5 { return nil }
        return String(format: "%@%.0f%%", pct >= 0 ? "+" : "", pct)
    }
    private var hrvTone: SignalTone {
        guard let v = health.todayHRV, let avg = health.averageHRV, avg > 0 else { return .neutral }
        let pct = (v - avg) / avg
        if pct <= -0.10 { return .bad }
        if pct >= 0.10  { return .good }
        return .neutral
    }

    private var rhrValue: String {
        guard let v = health.todayRestingHR else { return "—" }
        return String(format: "%.0f bpm", v)
    }
    private var rhrDelta: String? {
        guard let v = health.todayRestingHR, let avg = health.averageRestingHR, avg > 0 else { return nil }
        let diff = v - avg
        if abs(diff) < 3 { return nil }
        return String(format: "%@%.0f bpm", diff >= 0 ? "+" : "", diff)
    }
    private var rhrTone: SignalTone {
        guard let v = health.todayRestingHR, let avg = health.averageRestingHR, avg > 0 else { return .neutral }
        if v > avg + 5 { return .bad }
        if v < avg - 3 { return .good }
        return .neutral
    }

    private var confidenceIcon: String {
        switch plan.confidence {
        case .low:    return "questionmark.circle"
        case .medium: return "circle.lefthalf.filled"
        case .high:   return "checkmark.circle.fill"
        }
    }
}
