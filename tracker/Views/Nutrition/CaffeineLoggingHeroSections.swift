import SwiftUI

enum CaffeineLoggingHeroSections {

    static func decayTint(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(red: 0.85, green: 0.62, blue: 0.38) : .brown
    }

    static func heroCard(
        remaining: Double,
        readiness: (label: String, color: Color, icon: String),
        now: Date,
        entries: [CaffeineEntry],
        halfLife: Double,
        dailyLimit: Double,
        todayTotalMg: Double
    ) -> some View {
        HeroCard(palette: [
            Color(red: 0.55, green: 0.32, blue: 0.18),
            Color(red: 0.78, green: 0.45, blue: 0.18),
            Color(red: 0.95, green: 0.55, blue: 0.20)
        ]) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 20) {
                    ZStack {
                        Circle().stroke(.white.opacity(0.22), lineWidth: 9)
                        Circle()
                            .trim(from: 0, to: min(1.0, remaining / dailyLimit))
                            .stroke(.white, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.8), value: remaining)
                            .shadow(color: .white.opacity(0.45), radius: 6, y: 1)
                        VStack(spacing: 1) {
                            AnimatedInt(
                                value: Int(remaining),
                                font: .system(size: 28, weight: .black, design: .rounded),
                                color: .white
                            )
                            Text("mg")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.82))
                                .tracking(0.4)
                                .textCase(.uppercase)
                        }
                    }
                    .frame(width: 84, height: 84)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("System Caffeine")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))
                            .tracking(0.5)
                            .textCase(.uppercase)

                        HStack(spacing: 5) {
                            Image(systemName: readiness.icon).font(.caption.bold())
                            Text(readiness.label).font(.caption.weight(.bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 11).padding(.vertical, 5)
                        .background(.ultraThinMaterial.opacity(0.7), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 0.5))

                        if let clearTime = CaffeineEngine.clearTime(from: now, entries: entries, halfLifeHours: halfLife),
                           remaining >= 25 {
                            HStack(spacing: 4) {
                                Image(systemName: "moon.zzz.fill").font(.caption2).foregroundStyle(.white.opacity(0.8))
                                (Text("Clear by ") + Text(clearTime, format: .dateTime.hour().minute()).bold())
                                    .font(.caption).foregroundStyle(.white.opacity(0.85))
                            }
                        }

                        if let peak = CaffeineEngine.peakCaffeineInfo(entries: entries, halfLifeHours: halfLife, now: now) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.to.line").font(.caption2).foregroundStyle(.white.opacity(0.8))
                                (Text("Peak ~\(Int(peak.peakMg))mg at ")
                                 + Text(peak.peakTime, format: .dateTime.hour().minute()).bold())
                                    .font(.caption).foregroundStyle(.white.opacity(0.85))
                            }
                        }
                    }
                    Spacer()
                }

                HStack(spacing: 0) {
                    HeroStatCol(value: "\(Int(todayTotalMg))mg", label: "Today", icon: "cup.and.saucer.fill")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 36)
                    HeroStatCol(value: "\(Int(dailyLimit))mg", label: "Limit", icon: "gauge.with.needle")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 36)
                    HeroStatCol(value: "\(Int(remaining))mg", label: "Remaining", icon: "clock")
                }
                .padding(.vertical, 10)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(20)
        }
    }

    static func sleepReadinessPresentation(_ mg: Double) -> (label: String, color: Color, icon: String) {
        switch CaffeineEngine.SleepReadiness.level(forMg: mg) {
        case .readyForSleep: return ("Ready for Sleep", .green, "moon.zzz.fill")
        case .windingDown: return ("Winding Down", .yellow, "moon.fill")
        case .elevated: return ("Elevated", .orange, "exclamationmark.triangle.fill")
        case .tooStimulated: return ("Too Stimulated", .red, "bolt.fill")
        }
    }
}
