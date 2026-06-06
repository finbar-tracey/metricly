import SwiftUI
import Charts

enum SleepDetailStatsSections {

    static func statsCard(
        dailySleep: [(date: Date, minutes: Double)],
        averageSleep: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Stats", icon: "list.bullet.rectangle", color: .indigo)

            VStack(spacing: 0) {
                statsRow("Average", value: HealthFormatters.formatSleepShort(averageSleep))
                Divider().padding(.leading, 16)
                statsRow("Best Night", value: HealthFormatters.formatSleepShort(dailySleep.map(\.minutes).max() ?? 0))
                Divider().padding(.leading, 16)
                statsRow("Worst Night", value: HealthFormatters.formatSleepShort(dailySleep.map(\.minutes).min() ?? 0))
                Divider().padding(.leading, 16)
                statsRow("Nights Tracked", value: "\(dailySleep.count)")
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.tileRadius))
        }
        .appCard()
    }

    @ViewBuilder
    static func weeklyComparisonCard(
        thisWeekAvg: Double,
        lastWeekAvg: Double
    ) -> some View {
        if lastWeekAvg > 0 {
            let delta = thisWeekAvg - lastWeekAvg
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "This Week vs Last Week", icon: "arrow.left.arrow.right", color: .indigo)

                HStack(spacing: 0) {
                    VStack(spacing: 6) {
                        Text("This Week").font(.caption).foregroundStyle(.secondary)
                        Text(HealthFormatters.formatSleepShort(thisWeekAvg))
                            .font(.system(size: 24, weight: .bold, design: .rounded)).monospacedDigit()
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 6) {
                        Image(systemName: delta >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                            .font(.title2).foregroundStyle(delta >= 0 ? .green : .orange)
                        Text(HealthFormatters.formatSleepShort(abs(delta)))
                            .font(.caption.weight(.bold)).foregroundStyle(delta >= 0 ? .green : .orange)
                    }

                    VStack(spacing: 6) {
                        Text("Last Week").font(.caption).foregroundStyle(.secondary)
                        Text(HealthFormatters.formatSleepShort(lastWeekAvg))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .monospacedDigit().foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 8)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.tileRadius))
            }
            .appCard()
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    static func consistencyCard(detailedSleep: [DailySleepDetail]) -> some View {
        let consistencyData = detailedSleep.filter { $0.inBed != nil && $0.wakeUp != nil }
        if consistencyData.count >= 3 {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Bedtime Consistency", icon: "clock.fill", color: .indigo)

                VStack(spacing: 12) {
                    Chart(consistencyData, id: \.date) { day in
                        BarMark(x: .value("Date", day.date, unit: .day),
                                yStart: .value("Bed", SleepEngine.shiftedMinutes(day.inBed!)),
                                yEnd: .value("Wake", SleepEngine.shiftedMinutes(day.wakeUp!)))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.indigo.opacity(0.40), Color.indigo.opacity(0.18)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .cornerRadius(6)

                        PointMark(x: .value("Date", day.date, unit: .day),
                                  y: .value("Bed", SleepEngine.shiftedMinutes(day.inBed!)))
                            .foregroundStyle(Color.indigo)
                            .symbolSize(48)
                            .annotation(position: .overlay) {
                                Circle().fill(.white).frame(width: 4, height: 4)
                            }

                        PointMark(x: .value("Date", day.date, unit: .day),
                                  y: .value("Wake", SleepEngine.shiftedMinutes(day.wakeUp!)))
                            .foregroundStyle(Color.orange)
                            .symbolSize(48)
                            .annotation(position: .overlay) {
                                Circle().fill(.white).frame(width: 4, height: 4)
                            }
                    }
                    .chartYAxis {
                        AxisMarks(values: .stride(by: 60)) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(.secondary.opacity(0.3))
                            AxisValueLabel {
                                if let mins = value.as(Double.self) {
                                    Text(SleepEngine.formatShiftedMinutes(mins)).font(.caption2)
                                }
                            }
                        }
                    }
                    .frame(height: 170)

                    HStack(spacing: 16) {
                        HStack(spacing: 5) {
                            Circle().fill(Color.indigo).frame(width: 8, height: 8)
                            Text("Bedtime").font(.caption2).foregroundStyle(.secondary)
                        }
                        HStack(spacing: 5) {
                            Circle().fill(Color.orange).frame(width: 8, height: 8)
                            Text("Wake up").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .appCard()
        }
    }

    @ViewBuilder
    static func sleepDebtCard(detailedSleep: [DailySleepDetail]) -> some View {
        if !detailedSleep.isEmpty {
            let debtHours = SleepEngine.accumulatedDebtHours(detailedSleep: detailedSleep)
            let debtColor: Color = debtHours > 5 ? .red : debtHours > 2 ? .orange : .green

            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Sleep Debt", icon: "moon.zzz.fill", color: .indigo)

                VStack(spacing: 16) {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .lastTextBaseline, spacing: 4) {
                                Text(String(format: "%.1f", debtHours))
                                    .font(.system(size: 44, weight: .black, design: .rounded))
                                    .foregroundStyle(debtColor).monospacedDigit()
                                Text("hrs").font(.title3.weight(.semibold))
                                    .foregroundStyle(debtColor.opacity(0.75)).padding(.bottom, 6)
                            }
                            Text("accumulated over 7 days").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Gauge(value: min(debtHours, 10), in: 0...10) {
                            Image(systemName: "moon.zzz.fill")
                        }
                        .gaugeStyle(.accessoryCircular)
                        .tint(Gradient(colors: [.green, .yellow, .orange, .red]))
                        .frame(width: 58, height: 58)
                    }

                    GradientProgressBar(value: min(debtHours / 10, 1), color: debtColor, height: 8)

                    Text("Based on an 8-hour target. Each night short of the target adds to your debt.")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
            .appCard()
        }
    }

    private static func statsRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(.subheadline, design: .rounded, weight: .bold)).monospacedDigit()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}
