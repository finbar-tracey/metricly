import SwiftUI
import Charts

/// Caffeine daily history on `MetricDetailScaffold`.
enum CaffeineHistorySections {
    // MARK: - History (MetricDetailScaffold)

    struct HistorySection: View {
        @Binding var historyRange: CaffeineEngine.HistoryRange
        @Binding var scaffoldTimeRange: DetailTimeRange
        let entries: [CaffeineEntry]
        let dailyLimit: Double

        var body: some View {
            MetricDetailScaffold(
                navigationTitle: "",
                isLoading: false,
                isEmpty: entries.isEmpty,
                loadingMessage: "",
                emptyIcon: "cup.and.saucer.fill",
                emptyTitle: "No caffeine logged yet",
                emptySubtitle: "Log your first drink to see daily history.",
                timeRange: $scaffoldTimeRange,
                segmentColor: .brown,
                showRangePicker: false,
                hero: { EmptyView() },
                content: {
                    historyCard(
                        range: historyRange,
                        entries: entries,
                        dailyLimit: dailyLimit,
                        onSelectRange: { historyRange = $0 }
                    )
                }
            )
        }
    }

    static func historyCard(
        range: CaffeineEngine.HistoryRange,
        entries: [CaffeineEntry],
        dailyLimit: Double,
        onSelectRange: @escaping (CaffeineEngine.HistoryRange) -> Void
    ) -> some View {
        let days = range.dayCount
        let data = CaffeineEngine.dailyTotals(entries: entries, days: days)
        let stats = CaffeineEngine.historyStats(for: data)

        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Daily History", icon: "chart.bar.fill", color: .brown)

            HStack(spacing: 8) {
                ForEach(CaffeineEngine.HistoryRange.allCases, id: \.self) { bucket in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            onSelectRange(bucket)
                        }
                    } label: {
                        Text(bucket.rawValue)
                            .font(.caption.bold())
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(range == bucket ? Color.brown : Color(.secondarySystemFill),
                                        in: Capsule())
                            .foregroundStyle(range == bucket ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }

            HStack(spacing: 0) {
                historyStatCol("Avg/Day", value: "\(Int(stats.avgPerDay))mg")
                Rectangle().fill(Color(.separator)).frame(width: 1, height: 28)
                historyStatCol("Total", value: "\(Int(stats.total))mg")
                Rectangle().fill(Color(.separator)).frame(width: 1, height: 28)
                historyStatCol("Days", value: "\(stats.daysTracked)")
            }
            .padding(.vertical, 6)
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Chart {
                ForEach(data) { point in
                    BarMark(x: .value("Date", point.date, unit: .day), y: .value("mg", point.mg))
                        .foregroundStyle(point.mg > dailyLimit ? Color.red.gradient : Color.brown.gradient)
                        .cornerRadius(4)
                }
                RuleMark(y: .value("Limit", dailyLimit))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    .foregroundStyle(.red.opacity(0.5))
                    .annotation(position: .trailing, alignment: .trailing) {
                        Text("\(Int(dailyLimit))").font(.caption2).foregroundStyle(.red)
                    }
            }
            .chartYAxisLabel("mg")
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: days <= 7 ? 1 : 5)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: days <= 7 ? .dateTime.weekday(.abbreviated) : .dateTime.month(.abbreviated).day())
                }
            }
            .frame(height: 180).padding(.vertical, 4)
        }
        .appCard()
    }

    private static func historyStatCol(_ title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(.subheadline, design: .rounded, weight: .bold)).monospacedDigit()
            Text(title).font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

}
