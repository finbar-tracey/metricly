import SwiftUI

enum BodyFatEstimateSections {

    static func chartYDomain(historyData: [(date: Date, bf: Double)]) -> ClosedRange<Double> {
        BodyFatChartSections.chartYDomain(historyData: historyData)
    }

    static func setupRequiredCard(sexConfigured: Bool, heightCm: Double) -> some View {
        BodyFatHeroSections.setupRequiredCard(sexConfigured: sexConfigured, heightCm: heightCm)
    }

    static func measurementsNeededCard(
        isFemale: Bool,
        latestNeck: Double?,
        latestWaist: Double?,
        latestHips: Double?,
        isMetric: Bool
    ) -> some View {
        BodyFatHeroSections.measurementsNeededCard(
            isFemale: isFemale,
            latestNeck: latestNeck,
            latestWaist: latestWaist,
            latestHips: latestHips,
            isMetric: isMetric
        )
    }

    @ViewBuilder
    static func heroCard(
        bodyFatPercentage: Double?,
        category: (label: String, color: Color)
    ) -> some View {
        BodyFatHeroSections.heroCard(bodyFatPercentage: bodyFatPercentage, category: category)
    }

    @ViewBuilder
    static func compositionCard(
        leanMassKg: Double?,
        fatMassKg: Double?,
        latestWeight: Double?,
        weightUnit: WeightUnit,
        category: (label: String, color: Color)
    ) -> some View {
        BodyFatHeroSections.compositionCard(
            leanMassKg: leanMassKg,
            fatMassKg: fatMassKg,
            latestWeight: latestWeight,
            weightUnit: weightUnit,
            category: category
        )
    }

    static func trendChartCard(
        historyData: [(date: Date, bf: Double)],
        category: (label: String, color: Color)
    ) -> some View {
        BodyFatChartSections.trendChartCard(historyData: historyData, category: category)
    }

    static func referenceCard(
        isMale: Bool,
        category: (label: String, color: Color)
    ) -> some View {
        BodyFatChartSections.referenceCard(isMale: isMale, category: category)
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
        BodyFatChartSections.inputsCard(
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
