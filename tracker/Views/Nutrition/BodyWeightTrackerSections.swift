import SwiftUI
import SwiftData
import Charts

enum BodyWeightTrackerSections {

    static func heroCard(
        entries: [BodyWeightEntry],
        weightUnit: WeightUnit,
        summary: BodyWeightEngine.Summary,
        formatChange: (Double) -> String
    ) -> some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color.orange, Color.orange.opacity(0.65)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(.white.opacity(0.07)).frame(width: 200).offset(x: 160, y: -60)
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle().fill(.white.opacity(0.20)).frame(width: 52, height: 52)
                        Image(systemName: "scalemass.fill")
                            .font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Current Weight")
                            .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.75))
                        if let current = entries.first {
                            Text(weightUnit.format(current.weight))
                                .font(.system(size: 36, weight: .black, design: .rounded))
                                .foregroundStyle(.white).monospacedDigit()
                        }
                    }
                    Spacer()
                    if let change = summary.changeKg {
                        let isGain = weightUnit.display(change) > 0
                        HStack(spacing: 4) {
                            Image(systemName: isGain ? "arrow.up" : "arrow.down").font(.caption.bold())
                            Text(formatChange(change)).font(.caption.bold())
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.white.opacity(0.20), in: Capsule())
                        .foregroundStyle(.white)
                    }
                }
                HStack(spacing: 0) {
                    HeroStatCol(
                        value: summary.lowestKg.map { weightUnit.format($0) } ?? "—",
                        label: "Lowest"
                    )
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 28)
                    HeroStatCol(
                        value: summary.highestKg.map { weightUnit.format($0) } ?? "—",
                        label: "Highest"
                    )
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 28)
                    HeroStatCol(value: "\(entries.count)", label: "Entries")
                }
            }
            .padding(20)
        }
        .heroCard()
    }

    static func logCard(
        weightUnit: WeightUnit,
        newWeight: Binding<String>,
        selectedDate: Binding<Date>,
        isWeightFocused: FocusState<Bool>.Binding,
        onLog: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Log Weight", icon: "plus.circle.fill", color: .orange)
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    TextField("Weight (\(weightUnit.label))", text: newWeight)
                        .keyboardType(.decimalPad).focused(isWeightFocused).font(.subheadline)
                    Spacer()
                    DatePicker("", selection: selectedDate, displayedComponents: .date).labelsHidden()
                }
                .padding(.horizontal, 16).padding(.vertical, 13)
                Divider().padding(.leading, 16)
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onLog()
                } label: {
                    Label("Log Weight", systemImage: "plus.circle.fill")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .tracking(0.3)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            Group {
                                if newWeight.wrappedValue.isEmpty {
                                    Color(.systemFill)
                                } else {
                                    LinearGradient(
                                        colors: [Color.orange, AppTheme.Signal.actionOrange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                }
                            }
                        )
                        .foregroundStyle(newWeight.wrappedValue.isEmpty ? Color.secondary : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
                }
                .disabled(newWeight.wrappedValue.isEmpty)
                .buttonStyle(.pressableCard)
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    static func statsCard(
        entries: [BodyWeightEntry],
        weightUnit: WeightUnit,
        summary: BodyWeightEngine.Summary,
        formatChange: (Double) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Statistics", icon: "chart.bar.fill", color: .orange)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                statTile("Current", value: entries.first.map { weightUnit.format($0.weight) } ?? "—",
                         icon: "scalemass.fill", color: .orange)
                statTile("Lowest", value: summary.lowestKg.map { weightUnit.format($0) } ?? "—",
                         icon: "arrow.down.circle.fill", color: .green)
                statTile("Highest", value: summary.highestKg.map { weightUnit.format($0) } ?? "—",
                         icon: "arrow.up.circle.fill", color: .red)
                if let change = summary.changeKg {
                    let isGain = weightUnit.display(change) > 0
                    statTile("30d Change", value: formatChange(change),
                             icon: isGain ? "arrow.up.right" : "arrow.down.right", color: isGain ? .red : .green)
                } else {
                    statTile("30d Change", value: "—", icon: "minus.circle", color: .secondary)
                }
            }
        }
        .appCard()
    }

    private static func statTile(_ title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(colors: [color.opacity(0.26), color.opacity(0.12)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 34, height: 34)
                Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.subheadline.bold().monospacedDigit())
                Text(title).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    static func trendCard(
        chartEntries: [BodyWeightEntry],
        trend: [BodyWeightEngine.TrendPoint],
        weightUnit: WeightUnit,
        yDomain: ClosedRange<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "Trend", icon: "chart.line.uptrend.xyaxis", color: .orange)
                Spacer()
                trendLegend
            }
            Chart {
                ForEach(trend) { point in
                    AreaMark(x: .value("Date", point.date, unit: .day), y: .value("Weight", point.value))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(LinearGradient(
                            colors: [Color.orange.opacity(0.40), Color.orange.opacity(0.16), Color.orange.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom
                        ))
                }
                ForEach(chartEntries, id: \.persistentModelID) { entry in
                    PointMark(x: .value("Date", entry.date, unit: .day), y: .value("Weight", weightUnit.display(entry.weight)))
                        .symbolSize(20)
                        .foregroundStyle(Color.orange.opacity(0.35))
                }
                ForEach(trend) { point in
                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Weight", point.value),
                        series: .value("Series", "trend")
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(LinearGradient(colors: [Color.orange, AppTheme.Signal.actionOrange],
                                                    startPoint: .leading, endPoint: .trailing))
                }
            }
            .chartYAxisLabel(weightUnit.label)
            .chartYScale(domain: yDomain)
            .frame(height: 220).padding(.vertical, 12)
        }
        .appCard()
    }

    private static var trendLegend: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                Circle().fill(Color.orange.opacity(0.35)).frame(width: 6, height: 6)
                Text("Weigh-ins").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                Capsule().fill(Color.orange).frame(width: 12, height: 3)
                Text("7-day trend").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
            }
        }
    }

    static func historyCard(
        entries: [BodyWeightEntry],
        weightUnit: WeightUnit,
        onDelete: @escaping (BodyWeightEntry) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "History", icon: "clock.fill", color: .secondary)
            VStack(spacing: 0) {
                ForEach(Array(entries.prefix(30).enumerated()), id: \.element.persistentModelID) { idx, entry in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                                .font(.subheadline)
                            Text(entry.date, format: .dateTime.year())
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Text(weightUnit.format(entry.weight))
                            .font(.subheadline.bold().monospacedDigit())
                        changeIndicator(for: entry, in: entries, weightUnit: weightUnit)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    .contextMenu {
                        Button(role: .destructive) { onDelete(entry) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    if idx < min(entries.count, 30) - 1 { Divider().padding(.leading, 16) }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    @ViewBuilder
    private static func changeIndicator(
        for entry: BodyWeightEntry,
        in entries: [BodyWeightEntry],
        weightUnit: WeightUnit
    ) -> some View {
        if let index = entries.firstIndex(where: { $0.persistentModelID == entry.persistentModelID }),
           index + 1 < entries.count {
            let diff = entry.weight - entries[index + 1].weight
            if abs(diff) > 0.05 {
                Image(systemName: diff > 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption).foregroundStyle(diff > 0 ? .red : .green)
            }
        }
    }
}
