import SwiftUI
import SwiftData

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
                    BodyFatEstimateSections.setupRequiredCard(
                        sexConfigured: sexConfigured,
                        heightCm: heightCm
                    )
                } else if bodyFatPercentage == nil {
                    BodyFatEstimateSections.measurementsNeededCard(
                        isFemale: isFemale,
                        latestNeck: latestNeck,
                        latestWaist: latestWaist,
                        latestHips: latestHips,
                        isMetric: isMetric
                    )
                } else {
                    BodyFatEstimateSections.heroCard(
                        bodyFatPercentage: bodyFatPercentage,
                        category: category
                    )
                    if latestWeight != nil {
                        BodyFatEstimateSections.compositionCard(
                            leanMassKg: leanMassKg,
                            fatMassKg: fatMassKg,
                            latestWeight: latestWeight,
                            weightUnit: weightUnit,
                            category: category
                        )
                    }
                    if historyData.count >= 2 {
                        BodyFatEstimateSections.trendChartCard(
                            historyData: historyData,
                            category: category
                        )
                    }
                    BodyFatEstimateSections.referenceCard(isMale: isMale, category: category)
                    BodyFatEstimateSections.inputsCard(
                        isFemale: isFemale,
                        heightCm: heightCm,
                        latestNeck: latestNeck,
                        latestWaist: latestWaist,
                        latestHips: latestHips,
                        latestWeight: latestWeight,
                        isMetric: isMetric,
                        weightUnit: weightUnit
                    )
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Body Fat %")
    }
}

#Preview {
    NavigationStack { BodyFatEstimateView() }
        .modelContainer(for: [UserSettings.self, BodyMeasurement.self, BodyWeightEntry.self], inMemory: true)
}
