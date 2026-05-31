import SwiftUI

enum CardioGoalsSections {

    static func weeklyProgressCard(
        distanceGoalKm: Double,
        sessionGoal: Int,
        thisWeekDistanceKm: Double,
        thisWeekSessionCount: Int,
        distanceUnit: DistanceUnit,
        distanceProgress: Double,
        sessionProgress: Double
    ) -> some View {
        CardioGoalsProgressSections.weeklyProgressCard(
            distanceGoalKm: distanceGoalKm,
            sessionGoal: sessionGoal,
            thisWeekDistanceKm: thisWeekDistanceKm,
            thisWeekSessionCount: thisWeekSessionCount,
            distanceUnit: distanceUnit,
            distanceProgress: distanceProgress,
            sessionProgress: sessionProgress
        )
    }

    static func setGoalsCard(
        distanceGoalKm: Double,
        sessionGoal: Int,
        distanceUnit: DistanceUnit,
        onEditDistance: @escaping () -> Void,
        onEditSessions: @escaping () -> Void
    ) -> some View {
        CardioGoalsEditorSections.setGoalsCard(
            distanceGoalKm: distanceGoalKm,
            sessionGoal: sessionGoal,
            distanceUnit: distanceUnit,
            onEditDistance: onEditDistance,
            onEditSessions: onEditSessions
        )
    }

    static func distanceGoalSheet(
        draftDistanceKm: Binding<Double>,
        distanceUnit: DistanceUnit,
        onCancel: @escaping () -> Void,
        onSave: @escaping () -> Void
    ) -> some View {
        CardioGoalsEditorSections.distanceGoalSheet(
            draftDistanceKm: draftDistanceKm,
            distanceUnit: distanceUnit,
            onCancel: onCancel,
            onSave: onSave
        )
    }

    static func sessionGoalSheet(
        draftSessionCount: Binding<Int>,
        onCancel: @escaping () -> Void,
        onSave: @escaping () -> Void
    ) -> some View {
        CardioGoalsEditorSections.sessionGoalSheet(
            draftSessionCount: draftSessionCount,
            onCancel: onCancel,
            onSave: onSave
        )
    }

    static func streakCard(streak: Int) -> some View {
        CardioGoalsEditorSections.streakCard(streak: streak)
    }
}
