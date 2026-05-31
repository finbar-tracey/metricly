import SwiftUI
import SwiftData

// Split Home layout into dedicated section views so the root body avoids AnyView type-erasure.

struct HomeDashboardTopSection: View {
    let snapshot: HomeDashboardSnapshot
    @Bindable var store: HomeDashboardStore
    let greeting: String
    let healthKitEnabled: Bool
    let healthDataLoaded: Bool
    let hrv: Double?
    let sleepMinutes: Double
    let restingHR: Double?
    let animateRings: Bool
    let heroGradientColors: [Color]
    let topInsight: Insight?
    let shouldOfferInsightsTease: Bool
    let ctaKind: HomeContextualCTASection.Kind?
    let todaySteps: Double
    let activeCalories: Double
    let weightUnit: WeightUnit
    @Binding var tappedDayWorkout: Workout?
    @Binding var blockForDetailSheet: TrainingBlock?
    @Binding var showingAddWorkout: Bool
    let onPlanDetail: () -> Void
    let onInsertBlock: (TrainingBlock) -> Void
    let onOpenInsights: () -> Void

    var body: some View {
        VStack(spacing: AppTheme.sectionSpacing) {
            HomeHeroSection(
                greeting: greeting,
                healthKitEnabled: healthKitEnabled,
                healthDataLoaded: healthDataLoaded,
                recovery: store.recoveryResult,
                hrv: hrv,
                sleepMinutes: sleepMinutes,
                restingHR: restingHR,
                currentStreak: snapshot.currentStreak,
                allWorkouts: snapshot.allWorkouts,
                animateRings: animateRings,
                gradientColors: heroGradientColors,
                onWeekDayTapped: { tappedDayWorkout = $0 }
            )
            if HomeSyncStatusPill.shouldShow {
                HomeSyncStatusPill()
            }
            if let cta = ctaKind {
                HomeContextualCTASection(kind: cta, weightUnit: weightUnit)
            }
            HomeTrainingBlockChip(
                activeBlock: TrainingBlockEngine.currentBlock(in: snapshot.trainingBlocks),
                allBlocks: snapshot.trainingBlocks,
                onStartBlock: onInsertBlock,
                onTapActive: {
                    blockForDetailSheet = TrainingBlockEngine.currentBlock(in: snapshot.trainingBlocks)
                }
            )
            AdaptivePlanCardView(
                plan: store.todayPlan,
                onStart: { showingAddWorkout = true },
                onTapDetail: onPlanDetail
            )
            if let insight = topInsight {
                TopInsightCardView(insight: insight, onTap: onOpenInsights)
            } else if shouldOfferInsightsTease {
                InsightsTeaseCard(onTap: onOpenInsights)
            }
            HomePlanAndMetricsRow(
                plan: store.todayPlan,
                scheduledNameForToday: snapshot.settings.weeklyPlan[snapshot.todayWeekday],
                todaysWorkouts: snapshot.todaysWorkouts,
                todayTotalSets: snapshot.todayTotalSets,
                todayTotalVolumeKg: snapshot.todayTotalVolumeKg,
                weightUnit: weightUnit,
                healthDataLoaded: healthKitEnabled && healthDataLoaded,
                todaySteps: todaySteps,
                activeCalories: activeCalories,
                todayWaterMl: snapshot.hydration.todayMl,
                waterProgress: snapshot.hydration.progress,
                activitiesThisWeek: snapshot.activitiesThisWeek,
                weeklyGoal: snapshot.settings.weeklyGoal,
                currentStreak: snapshot.currentStreak,
                onStartWorkout: { showingAddWorkout = true }
            )
        }
    }
}

struct HomeDashboardMiddleSection: View {
    let snapshot: HomeDashboardSnapshot
    @Bindable var store: HomeDashboardStore
    let healthKitEnabled: Bool
    let healthDataLoaded: Bool
    let weightUnit: WeightUnit
    let totalCaffeineMg: Double
    let suggestedBedtime: (time: Date, delayedByCaffeine: Bool)
    let caffeineClearTime: Date?

    var body: some View {
        VStack(spacing: AppTheme.sectionSpacing) {
            if healthKitEnabled && healthDataLoaded {
                HomeMuscleReadinessSection(recovery: store.recoveryResult)
            }
            if !snapshot.caffeineEntries.isEmpty && totalCaffeineMg >= 25 {
                HomeBedtimeSuggestion(
                    bedtime: suggestedBedtime.time,
                    delayedByCaffeine: suggestedBedtime.delayedByCaffeine,
                    clearTime: caffeineClearTime
                )
            }
            HomeTrainingStatusSection(
                weeklyGoal: snapshot.settings.weeklyGoal,
                activitiesThisWeek: snapshot.activitiesThisWeek,
                currentStreak: snapshot.currentStreak,
                suggestedWorkoutType: store.recoveryResult.suggestedWorkoutType,
                averageRating: snapshot.averageRating
            )
            if !snapshot.cardioSessions.isEmpty {
                HomeCardioSection(sessions: Array(snapshot.cardioSessions), weightUnit: weightUnit)
            }
        }
    }
}

struct HomeDashboardBottomSection: View {
    let snapshot: HomeDashboardSnapshot
    let healthKitEnabled: Bool
    let healthDataLoaded: Bool
    let animateRings: Bool
    let todaySteps: Double
    let sleepMinutes: Double
    let restingHR: Double?
    let hrv: Double?
    let activeCalories: Double
    let totalCaffeineMg: Double
    let progressionSuggestions: [HomeProgressionSuggestion]
    let weightUnit: WeightUnit
    @Binding var showingAddWorkout: Bool

    var body: some View {
        VStack(spacing: AppTheme.sectionSpacing) {
            if !progressionSuggestions.isEmpty {
                HomeProgressionSection(
                    suggestions: progressionSuggestions.map {
                        HomeProgressionSection.Suggestion(
                            id: $0.id,
                            exerciseName: $0.exerciseName,
                            recommendation: $0.recommendation
                        )
                    },
                    weightUnit: weightUnit
                )
            }
            if healthKitEnabled && healthDataLoaded {
                HomeHealthGlanceSection(
                    healthDataLoaded: healthDataLoaded,
                    animateRings: animateRings,
                    todaySteps: todaySteps,
                    sleepMinutes: sleepMinutes,
                    restingHR: restingHR,
                    hrv: hrv,
                    activeCalories: activeCalories,
                    todayWaterMl: snapshot.hydration.todayMl,
                    waterProgress: snapshot.hydration.progress,
                    caffeineMg: totalCaffeineMg,
                    caffeineLimitMg: Double(snapshot.settings.dailyCaffeineLimit),
                    creatineTakenToday: snapshot.creatineTakenToday
                )
            }
            HomeRecentWorkoutsSection(
                workouts: snapshot.allWorkouts,
                onStartFirstWorkout: { showingAddWorkout = true }
            )
            HomeQuickLinksSection(inProgressWorkout: snapshot.inProgressWorkout)
        }
    }
}

struct HomeProgressionSuggestion: Identifiable {
    let id = UUID()
    let exerciseName: String
    let recommendation: ProgressionRecommendation
}
