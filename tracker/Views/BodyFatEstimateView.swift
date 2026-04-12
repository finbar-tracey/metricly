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

    // Latest measurements in cm
    private var latestNeck: Double? {
        measurements.first(where: { $0.site == "Neck" })?.value
    }

    private var latestWaist: Double? {
        measurements.first(where: { $0.site == "Waist" })?.value
    }

    private var latestHips: Double? {
        measurements.first(where: { $0.site == "Hips" })?.value
    }

    private var latestWeight: Double? {
        weightEntries.first?.weight
    }

    // U.S. Navy Method (all inputs in cm)
    // Male:   BF% = 86.010 × log10(waist - neck) - 70.041 × log10(height) + 36.76
    // Female: BF% = 163.205 × log10(waist + hip - neck) - 97.684 × log10(height) - 78.387
    private var bodyFatPercentage: Double? {
        guard heightCm > 0, sexConfigured,
              let neck = latestNeck, neck > 0,
              let waist = latestWaist, waist > 0 else { return nil }

        if isMale {
            let diff = waist - neck
            guard diff > 0 else { return nil }
            let bf = 86.010 * log10(diff) - 70.041 * log10(heightCm) + 36.76
            return max(2, min(60, bf))
        } else {
            guard let hips = latestHips, hips > 0 else { return nil }
            let sum = waist + hips - neck
            guard sum > 0 else { return nil }
            let bf = 163.205 * log10(sum) - 97.684 * log10(heightCm) - 78.387
            return max(2, min(60, bf))
        }
    }

    // Lean mass and fat mass
    private var fatMassKg: Double? {
        guard let bf = bodyFatPercentage, let weight = latestWeight else { return nil }
        return weight * bf / 100
    }

    private var leanMassKg: Double? {
        guard let fat = fatMassKg, let weight = latestWeight else { return nil }
        return weight - fat
    }

    // Category
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

    // Historical data for chart
    private var historyData: [(date: Date, bf: Double)] {
        guard heightCm > 0, sexConfigured else { return [] }

        // Group measurements by date, get the latest neck/waist/hips for each date
        let neckEntries = measurements.filter { $0.site == "Neck" }
        let waistEntries = measurements.filter { $0.site == "Waist" }
        let hipEntries = measurements.filter { $0.site == "Hips" }

        // Use waist dates as the anchor
        var results: [(date: Date, bf: Double)] = []
        let calendar = Calendar.current

        for waistEntry in waistEntries {
            let date = calendar.startOfDay(for: waistEntry.date)
            let waist = waistEntry.value

            // Find closest neck measurement on or before this date
            guard let neck = neckEntries.first(where: { $0.date <= waistEntry.date })?.value,
                  neck > 0 else { continue }

            if isMale {
                let diff = waist - neck
                guard diff > 0 else { continue }
                let bf = 86.010 * log10(diff) - 70.041 * log10(heightCm) + 36.76
                let clamped = max(2, min(60, bf))
                results.append((date, clamped))
            } else {
                guard let hips = hipEntries.first(where: { $0.date <= waistEntry.date })?.value,
                      hips > 0 else { continue }
                let sum = waist + hips - neck
                guard sum > 0 else { continue }
                let bf = 163.205 * log10(sum) - 97.684 * log10(heightCm) - 78.387
                let clamped = max(2, min(60, bf))
                results.append((date, clamped))
            }
        }

        return results.reversed() // chronological order
    }

    var body: some View {
        List {
            if !sexConfigured || heightCm <= 0 {
                setupRequiredSection
            } else if bodyFatPercentage == nil {
                measurementsNeededSection
            } else {
                resultSection
                if latestWeight != nil {
                    compositionSection
                }
                if historyData.count >= 2 {
                    chartSection
                }
                referenceSection
                inputsSection
            }
        }
        .navigationTitle("Body Fat %")
    }

    // MARK: - Setup Required

    private var setupRequiredSection: some View {
        Section {
            ContentUnavailableView {
                Label("Profile Setup Required", systemImage: "person.crop.circle.badge.exclamationmark")
            } description: {
                VStack(spacing: 8) {
                    if !sexConfigured {
                        Label("Set your biological sex in Settings", systemImage: "person.fill")
                    }
                    if heightCm <= 0 {
                        Label("Set your height in Settings", systemImage: "ruler")
                    }
                }
            } actions: {
                Text("Update in Settings → Profile")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Measurements Needed

    private var measurementsNeededSection: some View {
        Section {
            ContentUnavailableView {
                Label("Measurements Needed", systemImage: "ruler")
            } description: {
                VStack(alignment: .leading, spacing: 8) {
                    measurementStatus("Neck", value: latestNeck)
                    measurementStatus("Waist", value: latestWaist)
                    if isFemale {
                        measurementStatus("Hips", value: latestHips)
                    }
                }
            } actions: {
                Text("Log measurements in the Measurements tab")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.clear)
        }
    }

    private func measurementStatus(_ site: String, value: Double?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: value != nil ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(value != nil ? .green : .secondary)
            Text(site)
                .font(.subheadline)
            if let value {
                Spacer()
                Text(formatLength(value))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Result

    private var resultSection: some View {
        Section {
            VStack(spacing: 16) {
                // Gauge
                ZStack {
                    Circle()
                        .stroke(.quaternary, lineWidth: 12)
                        .frame(width: 140, height: 140)
                    Circle()
                        .trim(from: 0, to: min(1, (bodyFatPercentage ?? 0) / 50))
                        .stroke(category.color.gradient, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text(String(format: "%.1f%%", bodyFatPercentage ?? 0))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("Body Fat")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)

                // Category label
                Text(category.label)
                    .font(.headline)
                    .foregroundStyle(category.color)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(category.color.opacity(0.12), in: .capsule)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Body Composition

    private var compositionSection: some View {
        Section("Body Composition") {
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text(weightUnit.format(leanMassKg ?? 0))
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .monospacedDigit()
                    Text("Lean Mass")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    Text(weightUnit.format(fatMassKg ?? 0))
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .monospacedDigit()
                    Text("Fat Mass")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    Text(weightUnit.format(latestWeight ?? 0))
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .monospacedDigit()
                    Text("Total")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 4)

            // Visual bar
            GeometryReader { geo in
                let leanFraction = (latestWeight ?? 0) > 0 ? (leanMassKg ?? 0) / (latestWeight ?? 1) : 0.5
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue.gradient)
                        .frame(width: geo.size.width * leanFraction)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.orange.gradient)
                }
            }
            .frame(height: 20)

            HStack {
                Label("Lean", systemImage: "circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.blue)
                Spacer()
                Label("Fat", systemImage: "circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Trend Chart

    private var chartSection: some View {
        Section("Trend") {
            Chart(historyData, id: \.date) { point in
                LineMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("BF%", point.bf)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.accentColor)

                PointMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("BF%", point.bf)
                )
                .symbolSize(20)
                .foregroundStyle(Color.accentColor)
            }
            .chartYAxisLabel("%")
            .chartYScale(domain: chartYDomain)
            .frame(height: 180)
            .padding(.vertical, 8)
        }
    }

    private var chartYDomain: ClosedRange<Double> {
        let values = historyData.map(\.bf)
        guard let minVal = values.min(), let maxVal = values.max() else { return 0...50 }
        let padding = Swift.max(1, (maxVal - minVal) * 0.2)
        return (minVal - padding)...(maxVal + padding)
    }

    // MARK: - Reference Ranges

    private var referenceSection: some View {
        Section {
            if isMale {
                referenceRow("Essential Fat", range: "2–5%", color: .red)
                referenceRow("Athletic", range: "6–13%", color: .blue)
                referenceRow("Fit", range: "14–17%", color: .green)
                referenceRow("Average", range: "18–24%", color: .orange)
                referenceRow("Above Average", range: "25%+", color: .red)
            } else {
                referenceRow("Essential Fat", range: "10–13%", color: .red)
                referenceRow("Athletic", range: "14–20%", color: .blue)
                referenceRow("Fit", range: "21–24%", color: .green)
                referenceRow("Average", range: "25–31%", color: .orange)
                referenceRow("Above Average", range: "32%+", color: .red)
            }
        } header: {
            Text("Reference Ranges")
        } footer: {
            Text("Based on the American Council on Exercise (ACE) body fat categories.")
        }
    }

    private func referenceRow(_ label: String, range: String, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(range)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            if category.label == label {
                Image(systemName: "arrowtriangle.left.fill")
                    .font(.caption2)
                    .foregroundStyle(color)
            }
        }
    }

    // MARK: - Current Inputs

    private var inputsSection: some View {
        Section {
            inputRow("Height", value: formatHeight(heightCm))
            inputRow("Neck", value: latestNeck.map { formatLength($0) } ?? "—")
            inputRow("Waist", value: latestWaist.map { formatLength($0) } ?? "—")
            if isFemale {
                inputRow("Hips", value: latestHips.map { formatLength($0) } ?? "—")
            }
            if let weight = latestWeight {
                inputRow("Weight", value: weightUnit.format(weight))
            }
        } header: {
            Text("Current Inputs")
        } footer: {
            Text("Estimated using the U.S. Navy body fat formula. Update measurements in the Measurements tab for a new estimate.")
        }
    }

    private func inputRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    // MARK: - Helpers

    private func formatLength(_ cm: Double) -> String {
        if isMetric {
            return "\(String(format: "%.1f", cm)) cm"
        } else {
            return "\(String(format: "%.1f", cm / 2.54)) in"
        }
    }

    private func formatHeight(_ cm: Double) -> String {
        if cm <= 0 { return "Not Set" }
        if isMetric {
            return "\(Int(cm)) cm"
        } else {
            let totalInches = cm / 2.54
            let feet = Int(totalInches) / 12
            let inches = Int(totalInches) % 12
            return "\(feet)'\(inches)\""
        }
    }
}

#Preview {
    NavigationStack {
        BodyFatEstimateView()
    }
    .modelContainer(for: [UserSettings.self, BodyMeasurement.self, BodyWeightEntry.self], inMemory: true)
}
