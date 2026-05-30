import SwiftUI
import SwiftData
import Charts

struct BodyFatEstimateView: View {
    @Query private var settingsArray: [UserSettings]
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var measurements: [BodyMeasurement]
    @Query(sort: \BodyWeightEntry.date, order: .reverse) private var weightEntries: [BodyWeightEntry]
    @Environment(\.weightUnit) private var weightUnit

    private var settings: UserSettings? { settingsArray.first }
    private var isMetric: Bool { weightUnit == .kg }
    private var heightCm: Double { settings?.heightCm ?? 0 }
    private var isMale: Bool { settings?.biologicalSex == "male" }
    private var isFemale: Bool { settings?.biologicalSex == "female" }
    private var sexConfigured: Bool { isMale || isFemale }

    private var latestNeck: Double? { measurements.first(where: { $0.site == "Neck" })?.value }
    private var latestWaist: Double? { measurements.first(where: { $0.site == "Waist" })?.value }
    private var latestHips: Double? { measurements.first(where: { $0.site == "Hips" })?.value }
    private var latestWeight: Double? { weightEntries.first?.weight }

    // U.S. Navy Method
    private var bodyFatPercentage: Double? {
        guard heightCm > 0, sexConfigured,
              let neck = latestNeck, neck > 0,
              let waist = latestWaist, waist > 0 else { return nil }
        if isMale {
            let diff = waist - neck
            guard diff > 0 else { return nil }
            return max(2, min(60, 86.010 * log10(diff) - 70.041 * log10(heightCm) + 36.76))
        } else {
            guard let hips = latestHips, hips > 0 else { return nil }
            let sum = waist + hips - neck
            guard sum > 0 else { return nil }
            return max(2, min(60, 163.205 * log10(sum) - 97.684 * log10(heightCm) - 78.387))
        }
    }

    private var fatMassKg: Double? {
        guard let bf = bodyFatPercentage, let weight = latestWeight else { return nil }
        return weight * bf / 100
    }

    private var leanMassKg: Double? {
        guard let fat = fatMassKg, let weight = latestWeight else { return nil }
        return weight - fat
    }

    private var category: (label: String, color: Color) {
        guard let bf = bodyFatPercentage else { return ("Unknown", .secondary) }
        if isMale {
            switch bf {
            case ..<6: return ("Essential Fat", .red)
            case 6..<14: return ("Athletic", .blue)
            case 14..<18: return ("Fit", .green)
            case 18..<25: return ("Average", .orange)
            default: return ("Above Average", .red)
            }
        } else {
            switch bf {
            case ..<14: return ("Essential Fat", .red)
            case 14..<21: return ("Athletic", .blue)
            case 21..<25: return ("Fit", .green)
            case 25..<32: return ("Average", .orange)
            default: return ("Above Average", .red)
            }
        }
    }

    private var historyData: [(date: Date, bf: Double)] {
        guard heightCm > 0, sexConfigured else { return [] }
        let neckEntries = measurements.filter { $0.site == "Neck" }
        let waistEntries = measurements.filter { $0.site == "Waist" }
        let hipEntries = measurements.filter { $0.site == "Hips" }
        var results: [(date: Date, bf: Double)] = []
        let calendar = Calendar.current
        for waistEntry in waistEntries {
            let date = calendar.startOfDay(for: waistEntry.date)
            let waist = waistEntry.value
            guard let neck = neckEntries.first(where: { $0.date <= waistEntry.date })?.value, neck > 0 else { continue }
            if isMale {
                let diff = waist - neck
                guard diff > 0 else { continue }
                results.append((date, max(2, min(60, 86.010 * log10(diff) - 70.041 * log10(heightCm) + 36.76))))
            } else {
                guard let hips = hipEntries.first(where: { $0.date <= waistEntry.date })?.value, hips > 0 else { continue }
                let sum = waist + hips - neck
                guard sum > 0 else { continue }
                results.append((date, max(2, min(60, 163.205 * log10(sum) - 97.684 * log10(heightCm) - 78.387))))
            }
        }
        return results.reversed()
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                if !sexConfigured || heightCm <= 0 {
                    setupRequiredCard
                } else if bodyFatPercentage == nil {
                    measurementsNeededCard
                } else {
                    heroCard
                    if latestWeight != nil { compositionCard }
                    if historyData.count >= 2 { trendChartCard }
                    referenceCard
                    inputsCard
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Body Fat %")
    }

    // MARK: - Hero Card

    @ViewBuilder
    private var heroCard: some View {
        if let bf = bodyFatPercentage {
            let catColor = category.color
            HeroCard(palette: [catColor, catColor.opacity(0.78), catColor.opacity(0.55)]) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .center, spacing: 20) {
                        ZStack {
                            Circle().stroke(.white.opacity(0.25), lineWidth: 9)
                            Circle()
                                .trim(from: 0, to: min(1, bf / 50))
                                .stroke(.white, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut(duration: 0.8), value: bf)
                                .shadow(color: .white.opacity(0.45), radius: 6, y: 1)
                        }
                        .frame(width: 70, height: 70)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Body Fat")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.82))
                                .tracking(0.5)
                                .textCase(.uppercase)
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text(String(format: "%.1f", bf))
                                    .font(.system(size: 54, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                    .monospacedDigit()
                                    .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                                Text("%")
                                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.78))
                            }
                        }
                        Spacer()
                    }

                    Text(category.label)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(.ultraThinMaterial.opacity(0.7), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 0.5))

                    Text("Estimated using the U.S. Navy method")
                        .font(.caption).foregroundStyle(.white.opacity(0.78))
                }
                .padding(20)
            }
        }
    }

    // MARK: - Composition Card

    @ViewBuilder
    private var compositionCard: some View {
        if let lean = leanMassKg, let fat = fatMassKg, let total = latestWeight {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Body Composition", icon: "figure.stand", color: category.color)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    compTile("Lean Mass", value: weightUnit.format(lean), color: .blue)
                    compTile("Fat Mass", value: weightUnit.format(fat), color: .orange)
                    compTile("Total", value: weightUnit.format(total), color: .secondary)
                }

                GeometryReader { geo in
                    let leanFraction = total > 0 ? lean / total : 0.5
                    HStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue, AppTheme.Signal.calm],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * leanFraction)
                            .shadow(color: .blue.opacity(0.40), radius: 4, y: 1)
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.orange, AppTheme.Signal.actionOrange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: .orange.opacity(0.40), radius: 4, y: 1)
                    }
                }
                .frame(height: 22)

                HStack {
                    Label("LEAN", systemImage: "circle.fill")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(0.5)
                        .foregroundStyle(.blue)
                    Spacer()
                    Label("FAT", systemImage: "circle.fill")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(0.5)
                        .foregroundStyle(.orange)
                }
            }
            .appCard()
        }
    }

    private func compTile(_ title: String, value: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 16, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(color)
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.4)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [color.opacity(0.10), Color(.tertiarySystemGroupedBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(color.opacity(0.18), lineWidth: 0.5)
        )
    }

    // MARK: - Trend Chart Card

    private var trendChartCard: some View {
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
            .chartYScale(domain: chartYDomain)
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

    private var chartYDomain: ClosedRange<Double> {
        let values = historyData.map(\.bf)
        guard let minVal = values.min(), let maxVal = values.max() else { return 0...50 }
        let padding = Swift.max(1, (maxVal - minVal) * 0.2)
        return (minVal - padding)...(maxVal + padding)
    }

    // MARK: - Reference Card

    private var referenceCard: some View {
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

    // MARK: - Inputs Card

    private var inputsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Current Inputs", icon: "ruler", color: .secondary)

            VStack(spacing: 0) {
                let rows: [(String, String)] = [
                    ("Height", formatHeight(heightCm)),
                    ("Neck", latestNeck.map { formatLength($0) } ?? "—"),
                    ("Waist", latestWaist.map { formatLength($0) } ?? "—"),
                ] + (isFemale ? [("Hips", latestHips.map { formatLength($0) } ?? "—")] : [])
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

    // MARK: - Setup Required Card

    private var setupRequiredCard: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(Color.orange.opacity(0.12)).frame(width: 70, height: 70)
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 28, weight: .semibold)).foregroundStyle(.orange)
            }
            VStack(spacing: 6) {
                Text("Profile Setup Required").font(.headline)
                VStack(spacing: 4) {
                    if !sexConfigured {
                        Label("Set your biological sex in Settings", systemImage: "person.fill")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    if heightCm <= 0 {
                        Label("Set your height in Settings", systemImage: "ruler")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            Text("Update in Settings → Profile")
                .font(.caption).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
        .appCard()
    }

    // MARK: - Measurements Needed Card

    private var measurementsNeededCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Measurements Needed", icon: "ruler", color: .orange)

            VStack(spacing: 0) {
                measurementRow("Neck", value: latestNeck)
                Divider().padding(.leading, 16)
                measurementRow("Waist", value: latestWaist)
                if isFemale {
                    Divider().padding(.leading, 16)
                    measurementRow("Hips", value: latestHips)
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Text("Log measurements in the Measurements tab.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .appCard()
    }

    private func measurementRow(_ site: String, value: Double?) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(value != nil ? Color.green.opacity(0.12) : Color(.systemFill)).frame(width: 34, height: 34)
                Image(systemName: value != nil ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(value != nil ? .green : .secondary)
            }
            Text(site).font(.subheadline)
            Spacer()
            if let value {
                Text(formatLength(value)).font(.subheadline).foregroundStyle(.secondary)
            } else {
                Text("Not logged").font(.caption).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
    }

    // MARK: - Helpers

    private func formatLength(_ cm: Double) -> String {
        isMetric ? "\(String(format: "%.1f", cm)) cm" : "\(String(format: "%.1f", cm / 2.54)) in"
    }

    private func formatHeight(_ cm: Double) -> String {
        guard cm > 0 else { return "Not Set" }
        if isMetric { return "\(Int(cm)) cm" }
        let totalInches = cm / 2.54
        return "\(Int(totalInches) / 12)'\(Int(totalInches) % 12)\""
    }
}

#Preview {
    NavigationStack { BodyFatEstimateView() }
        .modelContainer(for: [UserSettings.self, BodyMeasurement.self, BodyWeightEntry.self], inMemory: true)
}
