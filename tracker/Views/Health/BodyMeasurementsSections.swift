import SwiftUI
import SwiftData
import Charts

enum BodyMeasurementsSections {

    static func sitePickerCard(
        allEntries: [BodyMeasurement],
        selectedSite: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Measurement Site", icon: "ruler.fill", color: .purple)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(BodyMeasurement.allSites, id: \.self) { site in
                        let count = allEntries.filter { $0.site == site }.count
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedSite.wrappedValue = site }
                        } label: {
                            VStack(spacing: 2) {
                                Text(site).font(.caption.bold())
                                if count > 0 {
                                    Text("\(count)").font(.system(size: 9))
                                        .foregroundStyle(selectedSite.wrappedValue == site ? .white.opacity(0.75) : .secondary)
                                }
                            }
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(selectedSite.wrappedValue == site ? Color.purple : Color(.secondarySystemFill), in: Capsule())
                            .foregroundStyle(selectedSite.wrappedValue == site ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .appCard()
    }

    static func heroCard(
        selectedSite: String,
        siteEntries: [BodyMeasurement],
        valueChange: Double?,
        formatLength: @escaping (Double) -> String,
        formatChange: @escaping (Double) -> String,
        displayLength: @escaping (Double) -> Double
    ) -> some View {
        HeroCard(palette: [
            AppTheme.Signal.focus,
            Color(red: 0.35, green: 0.55, blue: 0.85),
            Color(red: 0.20, green: 0.70, blue: 0.78)
        ]) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial.opacity(0.7))
                            .frame(width: 56, height: 56)
                            .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.5))
                        Image(systemName: "ruler.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedSite)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))
                            .tracking(0.5)
                            .textCase(.uppercase)
                        if let current = siteEntries.first {
                            Text(formatLength(current.value))
                                .font(.system(size: 42, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .monospacedDigit()
                                .shadow(color: .black.opacity(0.18), radius: 5, y: 3)
                        }
                    }
                    Spacer()
                    if let change = valueChange {
                        let isIncrease = displayLength(change) > 0
                        HStack(spacing: 4) {
                            Image(systemName: isIncrease ? "arrow.up" : "arrow.down").font(.caption.bold())
                            Text(formatChange(change)).font(.caption.bold())
                        }
                        .padding(.horizontal, 11).padding(.vertical, 6)
                        .background(.ultraThinMaterial.opacity(0.7), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 0.5))
                        .foregroundStyle(.white)
                    }
                }

                HStack(spacing: 0) {
                    HeroStatCol(
                        value: BodyMeasurementsEngine.lowestCm(siteEntries: siteEntries).map { formatLength($0) } ?? "—",
                        label: "Lowest"
                    )
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 28)
                    HeroStatCol(
                        value: BodyMeasurementsEngine.highestCm(siteEntries: siteEntries).map { formatLength($0) } ?? "—",
                        label: "Highest"
                    )
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 28)
                    HeroStatCol(value: "\(siteEntries.count)", label: "Entries")
                }
            }
            .padding(20)
        }
    }

    static func logCard(
        lengthLabel: String,
        newValue: Binding<String>,
        selectedDate: Binding<Date>,
        isValueFocused: FocusState<Bool>.Binding,
        onAdd: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Log Measurement", icon: "plus.circle.fill", color: .purple)

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    TextField("Value (\(lengthLabel))", text: newValue)
                        .keyboardType(.decimalPad).focused(isValueFocused).font(.subheadline)
                    Spacer()
                    DatePicker("", selection: selectedDate, displayedComponents: .date).labelsHidden()
                }
                .padding(.horizontal, 16).padding(.vertical, 13)

                Divider().padding(.leading, 16)

                Button(action: onAdd) {
                    Label("Log Measurement", systemImage: "plus.circle.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(newValue.wrappedValue.isEmpty ? Color(.systemFill) : Color.purple.opacity(0.9))
                        .foregroundStyle(newValue.wrappedValue.isEmpty ? Color.secondary : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
                }
                .disabled(newValue.wrappedValue.isEmpty)
                .buttonStyle(.plain)
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.tileRadius))
        }
        .appCard()
    }

    static func statsCard(
        siteEntries: [BodyMeasurement],
        valueChange: Double?,
        formatLength: @escaping (Double) -> String,
        formatChange: @escaping (Double) -> String,
        displayLength: @escaping (Double) -> Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Statistics", icon: "chart.bar.fill", color: .purple)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                statTile("Current", value: siteEntries.first.map { formatLength($0.value) } ?? "—",
                         icon: "ruler.fill", color: .purple)
                statTile("Lowest", value: BodyMeasurementsEngine.lowestCm(siteEntries: siteEntries).map { formatLength($0) } ?? "—",
                         icon: "arrow.down.circle.fill", color: .green)
                statTile("Highest", value: BodyMeasurementsEngine.highestCm(siteEntries: siteEntries).map { formatLength($0) } ?? "—",
                         icon: "arrow.up.circle.fill", color: .red)
                if let change = valueChange {
                    let isIncrease = displayLength(change) > 0
                    statTile("30d Change", value: formatChange(change),
                             icon: isIncrease ? "arrow.up.right" : "arrow.down.right",
                             color: isIncrease ? .orange : .green)
                } else {
                    statTile("30d Change", value: "—", icon: "minus.circle", color: .secondary)
                }
            }
        }
        .appCard()
    }

    static func statTile(_ title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.12)).frame(width: 34, height: 34)
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

    static func chartCard(
        selectedSite: String,
        chartEntries: [BodyMeasurement],
        chartYDomain: ClosedRange<Double>,
        lengthLabel: String,
        displayLength: @escaping (Double) -> Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Trend", icon: "chart.line.uptrend.xyaxis", color: .purple)
            Chart(chartEntries) { entry in
                LineMark(x: .value("Date", entry.date, unit: .day),
                         y: .value("Value", displayLength(entry.value)))
                    .interpolationMethod(.catmullRom).foregroundStyle(Color.purple)
                AreaMark(x: .value("Date", entry.date, unit: .day),
                         y: .value("Value", displayLength(entry.value)))
                    .interpolationMethod(.catmullRom).foregroundStyle(Color.purple.opacity(0.15).gradient)
                PointMark(x: .value("Date", entry.date, unit: .day),
                          y: .value("Value", displayLength(entry.value)))
                    .symbolSize(20).foregroundStyle(Color.purple)
            }
            .chartYAxisLabel(lengthLabel)
            .chartYScale(domain: chartYDomain)
            .frame(height: 200).padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(selectedSite) measurement trend, \(chartEntries.count) entries")
        }
        .appCard()
    }

    static func historyCard<Indicator: View>(
        selectedSite: String,
        siteEntries: [BodyMeasurement],
        formatLength: @escaping (Double) -> String,
        @ViewBuilder changeIndicator: @escaping (BodyMeasurement) -> Indicator,
        onDelete: @escaping (BodyMeasurement) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "History", icon: "clock.fill", color: .secondary)

            if siteEntries.isEmpty {
                Text("No entries for \(selectedSite) yet.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.tileRadius))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(siteEntries.prefix(30).enumerated()), id: \.element.persistentModelID) { idx, entry in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                                    .font(.subheadline)
                                Text(entry.date, format: .dateTime.year())
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }
                            Spacer()
                            Text(formatLength(entry.value)).font(.subheadline.bold().monospacedDigit())
                            changeIndicator(entry)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 11)
                        .accessibilityElement(children: .combine)
                        .contextMenu {
                            Button(role: .destructive) { onDelete(entry) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        if idx < min(siteEntries.count, 30) - 1 { Divider().padding(.leading, 16) }
                    }
                }
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.tileRadius))
            }
        }
        .appCard()
    }
}
