import SwiftUI

enum WeeklyMonthlyReportSections {

    static func periodPickerCard(selectedPeriod: Binding<ReportPeriod>) -> some View {
        WeeklyMonthlyReportHeroSections.periodPickerCard(selectedPeriod: selectedPeriod)
    }

    static func heroCard(snapshot: WeeklyMonthlyReportSnapshot, displayVolume: Double, weightUnit: WeightUnit) -> some View {
        WeeklyMonthlyReportHeroSections.heroCard(snapshot: snapshot, displayVolume: displayVolume, weightUnit: weightUnit)
    }

    @ViewBuilder
    static func trainingSummaryCard(snapshot: WeeklyMonthlyReportSnapshot, displayVolume: Double, weightUnit: WeightUnit) -> some View {
        WeeklyMonthlyReportHeroSections.trainingSummaryCard(snapshot: snapshot, displayVolume: displayVolume, weightUnit: weightUnit)
    }

    static func cardioCard(snapshot: WeeklyMonthlyReportSnapshot, weightUnit: WeightUnit) -> some View {
        WeeklyMonthlyReportCardSections.cardioCard(snapshot: snapshot, weightUnit: weightUnit)
    }

    static func prsCard(snapshot: WeeklyMonthlyReportSnapshot) -> some View {
        WeeklyMonthlyReportCardSections.prsCard(snapshot: snapshot)
    }

    static func muscleGroupsCard(snapshot: WeeklyMonthlyReportSnapshot) -> some View {
        WeeklyMonthlyReportCardSections.muscleGroupsCard(snapshot: snapshot)
    }

    @ViewBuilder
    static func bodyWeightCard(snapshot: WeeklyMonthlyReportSnapshot, weightUnit: WeightUnit) -> some View {
        WeeklyMonthlyReportCardSections.bodyWeightCard(snapshot: snapshot, weightUnit: weightUnit)
    }

    @ViewBuilder
    static func healthSummaryCard(
        avgSteps: Double?,
        avgSleepMinutes: Double?,
        avgRestingHR: Double?,
        avgHRV: Double?,
        prevAvgSteps: Double?,
        prevAvgSleepMinutes: Double?,
        prevAvgRestingHR: Double?,
        prevAvgHRV: Double?,
        isLoadingHealth: Bool
    ) -> some View {
        WeeklyMonthlyReportCardSections.healthSummaryCard(
            avgSteps: avgSteps,
            avgSleepMinutes: avgSleepMinutes,
            avgRestingHR: avgRestingHR,
            avgHRV: avgHRV,
            prevAvgSteps: prevAvgSteps,
            prevAvgSleepMinutes: prevAvgSleepMinutes,
            prevAvgRestingHR: prevAvgRestingHR,
            prevAvgHRV: prevAvgHRV,
            isLoadingHealth: isLoadingHealth
        )
    }

    static func consistencyCard(snapshot: WeeklyMonthlyReportSnapshot) -> some View {
        WeeklyMonthlyReportCardSections.consistencyCard(snapshot: snapshot)
    }

    static func statTile(icon: String, value: String, label: String, color: Color, change: Double? = nil) -> some View {
        WeeklyMonthlyReportHeroSections.statTile(icon: icon, value: value, label: label, color: color, change: change)
    }

    static func formatVolume(_ volume: Double, weightUnit: WeightUnit) -> String {
        WeeklyMonthlyReportHeroSections.formatVolume(volume, weightUnit: weightUnit)
    }
}
