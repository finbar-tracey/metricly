import SwiftUI
import Charts

enum BodyFatChartSections {

    static func chartYDomain(historyData: [(date: Date, bf: Double)]) -> ClosedRange<Double> {
        let values = historyData.map(\.bf)
        guard let minVal = values.min(), let maxVal = values.max() else { return 0...50 }
        let padding = Swift.max(1, (maxVal - minVal) * 0.2)
        return (minVal - padding)...(maxVal + padding)
    }

    static func trendChartCard(
        historyData: [(date: Date, bf: Double)],
        category: (label: String, color: Color)
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Trend", icon: "chart.line.downtrend.xyaxis", color: category.color)
            Chart(historyData, id: \.date) { point in
                AreaMark(x: .value("Date", point.date, unit: .day), y: .value("BF%", point.bf))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                category.color.opacity(0.55),
                                category.color.opacity(0.22),
                                category.color.opacity(0.02)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                LineMark(x: .value("Date", point.date, unit: .day), y: .value("BF%", point.bf))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [category.color, category.color.opacity(0.72)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: category.color.opacity(0.30), radius: 5, y: 2)
                PointMark(x: .value("Date", point.date, unit: .day), y: .value("BF%", point.bf))
                    .symbolSize(36)
                    .foregroundStyle(category.color)
                    .annotation(position: .overlay) {
                        Circle().fill(.white).frame(width: 4, height: 4)
                    }
            }
            .chartYAxisLabel("%")
            .chartYScale(domain: chartYDomain(historyData: historyData))
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
            .frame(height: 200).padding(.vertical, 12)
        }
        .appCard()
    }

    static func referenceCard(
        isMale: Bool,
        category: (label: String, color: Color)
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Reference Ranges", icon: "chart.bar.fill", color: .secondary)

            VStack(spacing: 0) {
                let ranges: [(String, String, Color)] = isMale
                    ? [("Essential Fat","2–5%",.red),("Athletic","6–13%",.blue),("Fit","14–17%",.green),("Average","18–24%",.orange),("Above Average","25%+",.red)]
                    : [("Essential Fat","10–13%",.red),("Athletic","14–20%",.blue),("Fit","21–24%",.green),("Average","25–31%",.orange),("Above Average","32%+",.red)]

                ForEach(Array(ranges.enumerated()), id: \.offset) { idx, triple in
                    let isCurrent = category.label == triple.0
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [triple.2, triple.2.opacity(0.6)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 5, height: 30)
                            .shadow(color: triple.2.opacity(0.40), radius: 4, x: 0, y: 0)
                            .padding(.leading, 16)
                        Text(triple.0)
                            .font(.system(size: 15, weight: isCurrent ? .bold : .semibold, design: .rounded))
                        Spacer()
                        Text(triple.1)
                            .font(.system(size: 15, weight: .black, design: .rounded).monospacedDigit())
                            .foregroundStyle(triple.2)
                        if isCurrent {
                            Text("YOU")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .tracking(0.5)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(
                                    LinearGradient(
                                        colors: [triple.2, triple.2.opacity(0.72)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    in: Capsule()
                                )
                                .shadow(color: triple.2.opacity(0.40), radius: 4, y: 2)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    if idx < ranges.count - 1 { Divider().padding(.leading, 41) }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.cardHairline, lineWidth: 0.5)
            )

            Text("Based on the American Council on Exercise (ACE) body fat categories.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .appCard()
    }

    static func inputsCard(
        isFemale: Bool,
        heightCm: Double,
        latestNeck: Double?,
        latestWaist: Double?,
        latestHips: Double?,
        latestWeight: Double?,
        isMetric: Bool,
        weightUnit: WeightUnit
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Current Inputs", icon: "ruler", color: .secondary)

            VStack(spacing: 0) {
                let rows: [(String, String)] = [
                    ("Height", formatHeight(heightCm, isMetric: isMetric)),
                    ("Neck", latestNeck.map { formatLength($0, isMetric: isMetric) } ?? "—"),
                    ("Waist", latestWaist.map { formatLength($0, isMetric: isMetric) } ?? "—"),
                ] + (isFemale ? [("Hips", latestHips.map { formatLength($0, isMetric: isMetric) } ?? "—")] : [])
                  + (latestWeight.map { [("Weight", weightUnit.format($0))] } ?? [])

                ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                    HStack {
                        Text(row.0.uppercased())
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(0.4)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(row.1)
                            .font(.system(size: 15, weight: .black, design: .rounded).monospacedDigit())
                            .foregroundStyle(row.1 == "—" ? .secondary : Color.primary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    if idx < rows.count - 1 { Divider().padding(.leading, 16) }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.cardHairline, lineWidth: 0.5)
            )

            Text("Update measurements in the Measurements tab for a new estimate.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .appCard()
    }

    static func formatLength(_ cm: Double, isMetric: Bool) -> String {
        isMetric ? "\(String(format: "%.1f", cm)) cm" : "\(String(format: "%.1f", cm / 2.54)) in"
    }

    private static func formatHeight(_ cm: Double, isMetric: Bool) -> String {
        guard cm > 0 else { return "Not Set" }
        if isMetric { return "\(Int(cm)) cm" }
        let totalInches = cm / 2.54
        return "\(Int(totalInches) / 12)'\(Int(totalInches) % 12)\""
    }
}
