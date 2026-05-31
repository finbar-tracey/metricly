import SwiftUI
import SwiftData

struct CardioGoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.weightUnit) private var weightUnit
    @Query private var settingsArray: [UserSettings]
    @Query(sort: \CardioSession.date, order: .reverse) private var sessions: [CardioSession]

    @State private var editingDistance = false
    @State private var editingSessions = false
    @State private var draftDistanceKm: Double = 0
    @State private var draftSessionCount: Int = 0

    private var settings: UserSettings? { settingsArray.first }
    private var distanceUnit: DistanceUnit { weightUnit.distanceUnit }

    private var weekStart: Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .distantPast
    }

    private var thisWeekSessions: [CardioSession] {
        sessions.filter { $0.date >= weekStart }
    }

    private var thisWeekDistanceKm: Double {
        thisWeekSessions.reduce(0) { $0 + $1.distanceMeters } / 1000
    }

    private var distanceGoalKm: Double { settings?.weeklyCardioDistanceGoalKm ?? 0 }
    private var sessionGoal: Int { settings?.weeklyCardioSessionGoal ?? 0 }

    private var distanceProgress: Double {
        guard distanceGoalKm > 0 else { return 0 }
        return min(1.0, thisWeekDistanceKm / distanceGoalKm)
    }

    private var sessionProgress: Double {
        guard sessionGoal > 0 else { return 0 }
        return min(1.0, Double(thisWeekSessions.count) / Double(sessionGoal))
    }

    private var currentStreak: Int {
        var streak = 0
        var weekOffset = 0
        let calendar = Calendar.current
        while true {
            guard let weekInterval = calendar.dateInterval(
                of: .weekOfYear,
                for: calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: .now) ?? .now
            ) else { break }
            let hadSession = sessions.contains { $0.date >= weekInterval.start && $0.date < weekInterval.end }
            if hadSession { streak += 1; weekOffset += 1 } else { break }
        }
        return streak
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                CardioGoalsSections.weeklyProgressCard(
                    distanceGoalKm: distanceGoalKm,
                    sessionGoal: sessionGoal,
                    thisWeekDistanceKm: thisWeekDistanceKm,
                    thisWeekSessionCount: thisWeekSessions.count,
                    distanceUnit: distanceUnit,
                    distanceProgress: distanceProgress,
                    sessionProgress: sessionProgress
                )
                CardioGoalsSections.setGoalsCard(
                    distanceGoalKm: distanceGoalKm,
                    sessionGoal: sessionGoal,
                    distanceUnit: distanceUnit,
                    onEditDistance: { editingDistance = true },
                    onEditSessions: { editingSessions = true }
                )
                CardioGoalsSections.streakCard(streak: currentStreak)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Cardio Goals")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            draftDistanceKm = settings?.weeklyCardioDistanceGoalKm ?? 0
            draftSessionCount = settings?.weeklyCardioSessionGoal ?? 0
        }
        .sheet(isPresented: $editingDistance) {
            CardioGoalsSections.distanceGoalSheet(
                draftDistanceKm: $draftDistanceKm,
                distanceUnit: distanceUnit,
                onCancel: {
                    draftDistanceKm = settings?.weeklyCardioDistanceGoalKm ?? 0
                    editingDistance = false
                },
                onSave: {
                    settings?.weeklyCardioDistanceGoalKm = draftDistanceKm
                    modelContext.saveOrLog()
                    editingDistance = false
                }
            )
        }
        .sheet(isPresented: $editingSessions) {
            CardioGoalsSections.sessionGoalSheet(
                draftSessionCount: $draftSessionCount,
                onCancel: {
                    draftSessionCount = settings?.weeklyCardioSessionGoal ?? 0
                    editingSessions = false
                },
                onSave: {
                    settings?.weeklyCardioSessionGoal = draftSessionCount
                    modelContext.saveOrLog()
                    editingSessions = false
                }
            )
        }
    }
}
