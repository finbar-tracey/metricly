import SwiftUI

enum MuscleRecoveryHeroSection {

    static func heroCard(
        recoveryResult: RecoveryResult,
        healthDataLoaded: Bool,
        lastNightSleep: Double,
        latestHRV: Double?,
        averageHRV: Double?,
        todayRestingHR: Double?,
        averageRestingHR: Double?
    ) -> some View {
        let score = recoveryResult.readinessScore
        let palette: [Color] = score >= 0.70
            ? AppTheme.Gradients.recovery
            : (score >= 0.45 ? AppTheme.Gradients.caution : AppTheme.Gradients.strain)
        let signals = availableSignals(
            lastNightSleep: lastNightSleep,
            latestHRV: latestHRV,
            averageHRV: averageHRV,
            todayRestingHR: todayRestingHR,
            averageRestingHR: averageRestingHR
        )

        return HeroCard(palette: palette) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center, spacing: 20) {
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.25), lineWidth: 9)
                        Circle()
                            .trim(from: 0, to: score)
                            .stroke(.white, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.8), value: score)
                            .shadow(color: .white.opacity(0.45), radius: 6, y: 1)
                    }
                    .frame(width: 72, height: 72)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(
                            localized: "Overall Readiness",
                            comment: "Hero label above the recovery readiness percentage"
                        ))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))
                            .tracking(0.5)
                            .textCase(.uppercase)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            AnimatedInt(
                                value: Int(score * 100),
                                font: .system(size: 56, weight: .black, design: .rounded),
                                color: .white
                            )
                            .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                            Text("%")
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white.opacity(0.78))
                        }
                    }
                }

                Text(RecoveryEngine.readinessLabel(score))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.ultraThinMaterial.opacity(0.7), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 0.5))

                Text(healthDataLoaded
                    ? String(localized: "Based on workouts, sleep, heart rate & HRV",
                             comment: "Hero subtitle shown when HealthKit data is loaded")
                    : String(localized: "Based on recent workouts and training volume",
                             comment: "Hero subtitle shown when HealthKit data is not yet loaded"))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.78))

                if healthDataLoaded && !signals.isEmpty {
                    Rectangle()
                        .fill(.white.opacity(0.16))
                        .frame(height: 1)
                    heroSignalStrip(signals: signals)
                }
            }
            .padding(20)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(
            localized: "Overall readiness \(Int(score * 100)) percent. \(RecoveryEngine.readinessLabel(score))",
            comment: "VoiceOver label for the recovery hero card combining the numeric score and the readiness sentence"
        ))
    }

    // MARK: - Hero Signal Strip

    private struct HeroSignal: Identifiable {
        let id = UUID()
        let value: String
        let label: String
        let dot: AnyView
    }

    private static func availableSignals(
        lastNightSleep: Double,
        latestHRV: Double?,
        averageHRV: Double?,
        todayRestingHR: Double?,
        averageRestingHR: Double?
    ) -> [HeroSignal] {
        var out: [HeroSignal] = []
        if let hrv = latestHRV {
            out.append(HeroSignal(
                value: "\(Int(hrv)) ms",
                label: "HRV",
                dot: AnyView(hrvIndicator(hrv: hrv, averageHRV: averageHRV))
            ))
        }
        if let rhr = todayRestingHR {
            out.append(HeroSignal(
                value: "\(Int(rhr)) bpm",
                label: "Resting HR",
                dot: AnyView(rhrIndicator(rhr: rhr, averageRestingHR: averageRestingHR))
            ))
        }
        if lastNightSleep > 0 {
            let h = Int(lastNightSleep) / 60, m = Int(lastNightSleep) % 60
            out.append(HeroSignal(
                value: "\(h)h \(m)m",
                label: "Sleep",
                dot: AnyView(sleepIndicator(lastNightSleep: lastNightSleep))
            ))
        }
        return out
    }

    private static func heroSignalStrip(signals: [HeroSignal]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(signals.enumerated()), id: \.element.id) { index, sig in
                if index > 0 {
                    Rectangle()
                        .fill(.white.opacity(0.22))
                        .frame(width: 1, height: 30)
                }
                VStack(spacing: 4) {
                    Text(sig.value)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    HStack(spacing: 4) {
                        sig.dot
                        Text(sig.label)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.62))
                            .tracking(0.4)
                            .textCase(.uppercase)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Health Indicators

    @ViewBuilder
    private static func hrvIndicator(hrv: Double, averageHRV: Double?) -> some View {
        if let avg = averageHRV, avg > 0 {
            let ratio = hrv / avg
            Circle()
                .fill(healthTint(ratio >= 1.0 ? .good : ratio >= 0.85 ? .borderline : .bad))
                .frame(width: 10, height: 10)
        }
    }

    @ViewBuilder
    private static func rhrIndicator(rhr: Double, averageRestingHR: Double?) -> some View {
        if let avg = averageRestingHR, avg > 0 {
            let ratio = rhr / avg
            Circle()
                .fill(healthTint(ratio <= 1.05 ? .good : ratio <= 1.10 ? .borderline : .bad))
                .frame(width: 10, height: 10)
        }
    }

    @ViewBuilder
    private static func sleepIndicator(lastNightSleep: Double) -> some View {
        let hours = lastNightSleep / 60
        Circle()
            .fill(healthTint(hours >= 7 ? .good : hours >= 6 ? .borderline : .bad))
            .frame(width: 10, height: 10)
    }

    private enum HealthState { case good, borderline, bad }

    private static func healthTint(_ state: HealthState) -> Color {
        switch state {
        case .good:       return AppTheme.Signal.recovery
        case .borderline: return AppTheme.Signal.warning
        case .bad:        return AppTheme.Signal.caution
        }
    }
}
