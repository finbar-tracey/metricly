import SwiftUI

enum SleepDetailHeroSections {

    static func heroCard(
        todaySleep: (totalMinutes: Double, inBed: Date?, wakeUp: Date?, stages: [SleepStage]),
        detailedSleep: [DailySleepDetail]
    ) -> some View {
        let score = SleepEngine.sleepScore(todaySleep: todaySleep, detailedSleep: detailedSleep)
        let scoreLabel = SleepEngine.sleepScoreLabel(score: score)
        let efficiency = SleepEngine.sleepEfficiency(
            totalMinutes: todaySleep.totalMinutes,
            inBed: todaySleep.inBed,
            wakeUp: todaySleep.wakeUp
        )

        return HeroCard(palette: AppTheme.Gradients.sleep) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center, spacing: 20) {
                    ZStack {
                        Circle().stroke(.white.opacity(0.22), lineWidth: 9)
                        Circle()
                            .trim(from: 0, to: min(1.0, todaySleep.totalMinutes / 480))
                            .stroke(.white, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.8), value: score)
                            .shadow(color: .white.opacity(0.45), radius: 6, y: 1)
                        VStack(spacing: 1) {
                            AnimatedInt(
                                value: score,
                                font: .system(size: 32, weight: .black, design: .rounded),
                                color: .white
                            )
                            Text(scoreLabel)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.82))
                                .tracking(0.4)
                                .textCase(.uppercase)
                        }
                    }
                    .frame(width: 92, height: 92)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Sleep score \(score), \(scoreLabel)")

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Last Night")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))
                            .tracking(0.5)
                            .textCase(.uppercase)
                        Text(HealthFormatters.formatSleepShort(todaySleep.totalMinutes))
                            .font(.system(size: 42, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.18), radius: 5, y: 3)
                    }
                }

                HStack(spacing: 0) {
                    if let inBed = todaySleep.inBed {
                        sleepStatColumn(
                            icon: "bed.double.fill",
                            label: "Bedtime",
                            value: inBed.formatted(.dateTime.hour().minute())
                        )
                    }
                    if let wake = todaySleep.wakeUp {
                        sleepStatColumn(
                            icon: "sun.horizon.fill",
                            label: "Wake",
                            value: wake.formatted(.dateTime.hour().minute())
                        )
                    }
                    if let eff = efficiency {
                        sleepStatColumn(icon: "gauge.with.needle.fill", label: "Efficiency", value: "\(Int(eff))%")
                    }
                }
            }
        }
    }

    private static func sleepStatColumn(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 14)).foregroundStyle(.white.opacity(0.75))
            Text(value).font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.white.opacity(0.60))
        }
        .frame(maxWidth: .infinity)
    }
}
