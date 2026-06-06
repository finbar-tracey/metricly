import SwiftUI
import Charts

enum SleepDetailTrendSections {

    static func timelineCard(stages: [SleepStage]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Sleep Timeline", icon: "waveform.path.ecg", color: .indigo)
            Chart(stages) { stage in
                RectangleMark(
                    xStart: .value("Start", stage.start),
                    xEnd: .value("End", stage.end),
                    yStart: .value("StageStart", stageDepth(stage.type)),
                    yEnd: .value("StageEnd", stageDepth(stage.type) + 0.8)
                )
                .foregroundStyle(stage.type.color)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            .chartYScale(domain: -0.2...3.8)
            .chartYAxis {
                AxisMarks(values: [0.4, 1.4, 2.4, 3.4]) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(stageLabelForDepth(v)).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 1)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(.secondary.opacity(0.3))
                    AxisValueLabel(format: .dateTime.hour()).font(.caption2)
                }
            }
            .frame(height: 150)
        }
        .appCard()
    }

    static func stageCardsCard(
        todaySleep: (totalMinutes: Double, inBed: Date?, wakeUp: Date?, stages: [SleepStage])
    ) -> some View {
        let grouped = Dictionary(grouping: todaySleep.stages) { $0.type }
        let totalMinutes = todaySleep.stages.filter { $0.type != .awake }.reduce(0.0) { $0 + $1.durationMinutes }
        let stageOrder: [SleepStage.StageType] = [.deep, .core, .rem, .awake]

        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Sleep Stages", icon: "chart.pie.fill", color: .indigo)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(stageOrder, id: \.rawValue) { stageType in
                    let minutes = grouped[stageType]?.reduce(0.0) { $0 + $1.durationMinutes } ?? 0
                    if minutes > 0 {
                        let totalForPercentage = stageType == .awake
                            ? todaySleep.stages.reduce(0.0) { $0 + $1.durationMinutes }
                            : totalMinutes
                        let percentage = totalForPercentage > 0 ? (minutes / totalForPercentage) * 100 : 0
                        stageCard(type: stageType, minutes: minutes, percentage: percentage)
                    }
                }
            }
        }
        .appCard()
    }

    static func durationTrendCard(
        chartSleep: [(date: Date, minutes: Double)],
        timeRange: DetailTimeRange,
        isLoading: Bool,
        onSelectRange: @escaping (DetailTimeRange) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Duration Trend", icon: "chart.bar.fill", color: .indigo)

            HStack(spacing: 8) {
                ForEach(DetailTimeRange.allCases) { range in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { onSelectRange(range) }
                    } label: {
                        Text(range.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(
                                timeRange == range ? AnyShapeStyle(Color.indigo) : AnyShapeStyle(Color(.secondarySystemFill)),
                                in: Capsule()
                            )
                            .foregroundStyle(timeRange == range ? .white : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }

            if !chartSleep.isEmpty {
                Chart {
                    ForEach(chartSleep, id: \.date) { point in
                        BarMark(x: .value("Date", point.date, unit: .day),
                                y: .value("Hours", point.minutes / 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.42, green: 0.30, blue: 0.78),
                                        Color(red: 0.30, green: 0.40, blue: 0.85)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .cornerRadius(6)
                    }
                    RuleMark(y: .value("Target", 8))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                        .foregroundStyle(.secondary.opacity(0.6))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("8h target")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                }
                .chartYAxisLabel("hours")
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisGridLine().foregroundStyle(AppTheme.chartGrid)
                        AxisValueLabel().font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(AppTheme.chartGrid)
                        AxisValueLabel().font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .frame(height: 220).padding(.vertical, 12)
            } else if !isLoading {
                Text("No sleep data available.")
                    .foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 80)
            }
        }
        .appCard()
    }

    // MARK: - Private helpers

    private static func stageCard(type: SleepStage.StageType, minutes: Double, percentage: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Circle().fill(type.color).frame(width: 8, height: 8)
                Text(type.rawValue).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                comparisonBadge(actual: percentage, recommended: recommendedRange(for: type))
            }
            Text(HealthFormatters.formatSleepShort(minutes))
                .font(.system(size: 22, weight: .bold, design: .rounded)).monospacedDigit()
            GradientProgressBar(value: percentage / 100, color: type.color, height: 6)
            Text("\(Int(percentage))% of sleep").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.tileRadius))
        .accessibilityElement(children: .combine)
    }

    private static func stageDepth(_ type: SleepStage.StageType) -> Double {
        switch type {
        case .deep: return 0
        case .core: return 1
        case .unspecified: return 1
        case .rem: return 2
        case .awake: return 3
        }
    }

    private static func stageLabelForDepth(_ value: Double) -> String {
        switch value {
        case 0.4: return "Deep"
        case 1.4: return "Core"
        case 2.4: return "REM"
        case 3.4: return "Awake"
        default: return ""
        }
    }

    private static func recommendedRange(for type: SleepStage.StageType) -> ClosedRange<Double> {
        switch type {
        case .deep: return 15...20
        case .core: return 40...60
        case .rem: return 20...25
        case .awake: return 0...5
        case .unspecified: return 0...100
        }
    }

    @ViewBuilder
    private static func comparisonBadge(actual: Double, recommended: ClosedRange<Double>) -> some View {
        if actual < recommended.lowerBound {
            Text("Low").font(.caption2.weight(.bold))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.orange.opacity(0.15), in: Capsule()).foregroundStyle(.orange)
        } else if actual > recommended.upperBound {
            Text("High").font(.caption2.weight(.bold))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.yellow.opacity(0.15), in: Capsule()).foregroundStyle(.yellow)
        } else {
            Text("Normal").font(.caption2.weight(.bold))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.green.opacity(0.15), in: Capsule()).foregroundStyle(.green)
        }
    }
}
