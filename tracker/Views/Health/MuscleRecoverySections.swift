import SwiftUI

enum MuscleRecoverySections {

    /// The latest report per group within the 48h window. One row per
    /// affected group, level > 0 only (level 0 = "no soreness" and
    /// doesn't warrant a row).
    static func activeSorenessReports(from sorenessReports: [SorenessEntry]) -> [SorenessEntry] {
        let cutoff = Date.now.addingTimeInterval(-EngineConstants.Recovery.sorenessLookbackHours * 3600)
        var seen = Set<MuscleGroup>()
        return sorenessReports
            .filter { $0.date >= cutoff && $0.level > 0 }
            .filter { entry in
                guard !seen.contains(entry.group) else { return false }
                seen.insert(entry.group)
                return true
            }
    }

    static func heroCard(
        recoveryResult: RecoveryResult,
        healthDataLoaded: Bool,
        lastNightSleep: Double,
        latestHRV: Double?,
        averageHRV: Double?,
        todayRestingHR: Double?,
        averageRestingHR: Double?
    ) -> some View {
        MuscleRecoveryHeroSection.heroCard(
            recoveryResult: recoveryResult,
            healthDataLoaded: healthDataLoaded,
            lastNightSleep: lastNightSleep,
            latestHRV: latestHRV,
            averageHRV: averageHRV,
            todayRestingHR: todayRestingHR,
            averageRestingHR: averageRestingHR
        )
    }

    static func externalActivityCard(
        externalWorkouts: [ExternalWorkout],
        weightUnit: WeightUnit
    ) -> some View {
        MuscleRecoveryListSection.externalActivityCard(
            externalWorkouts: externalWorkouts,
            weightUnit: weightUnit
        )
    }

    static func sorenessReportsCard(activeSorenessReports: [SorenessEntry]) -> some View {
        MuscleRecoveryListSection.sorenessReportsCard(activeSorenessReports: activeSorenessReports)
    }

    static func muscleGroupsCard(recoveryResult: RecoveryResult) -> some View {
        MuscleRecoveryListSection.muscleGroupsCard(recoveryResult: recoveryResult)
    }

    static func suggestedCard(recoveryResult: RecoveryResult) -> some View {
        MuscleRecoveryListSection.suggestedCard(recoveryResult: recoveryResult)
    }
}
