import Foundation
import HealthKit

/// Pure achievement evaluation from workouts, cardio, and HealthKit snapshots.
enum AchievementsEngine {

    struct Inputs {
        let finishedWorkouts: [Workout]
        let allWorkouts: [Workout]
        let cardioSessions: [CardioSession]
        let bodyWeights: [BodyWeightEntry]
        let stepsData: [(date: Date, steps: Double)]
        let sleepData: [(date: Date, minutes: Double)]
        let externalWorkouts: [ExternalWorkout]
    }

    static func allAchievements(from inputs: Inputs) -> [Achievement] {
        gymAchievements(from: inputs)
        + runningAchievements(from: inputs)
        + stepsAchievements(from: inputs)
        + sleepAchievements(from: inputs)
    }

    // MARK: - Gym

    private static func gymAchievements(from inputs: Inputs) -> [Achievement] {
        var list: [Achievement] = []
        let finishedWorkouts = inputs.finishedWorkouts
        let count = finishedWorkouts.count

        list.append(Achievement(id: "first_workout", name: "First Step", description: "Complete your first workout",
            icon: "figure.strengthtraining.traditional", tier: .bronze, category: .gym,
            isUnlocked: count >= 1, progress: min(1, Double(count) / 1),
            unlockedDate: count >= 1 ? sortedDate(at: 0, workouts: finishedWorkouts) : nil))
        list.append(Achievement(id: "ten_workouts", name: "Getting Serious", description: "Complete 10 workouts",
            icon: "flame", tier: .bronze, category: .gym,
            isUnlocked: count >= 10, progress: min(1, Double(count) / 10),
            unlockedDate: sortedDate(at: 9, workouts: finishedWorkouts)))
        list.append(Achievement(id: "25_workouts", name: "Quarter Century", description: "Complete 25 workouts",
            icon: "star", tier: .silver, category: .gym,
            isUnlocked: count >= 25, progress: min(1, Double(count) / 25),
            unlockedDate: sortedDate(at: 24, workouts: finishedWorkouts)))
        list.append(Achievement(id: "50_workouts", name: "Half Century", description: "Complete 50 workouts",
            icon: "star.fill", tier: .silver, category: .gym,
            isUnlocked: count >= 50, progress: min(1, Double(count) / 50),
            unlockedDate: sortedDate(at: 49, workouts: finishedWorkouts)))
        list.append(Achievement(id: "100_workouts", name: "Century Club", description: "Complete 100 workouts",
            icon: "trophy", tier: .gold, category: .gym,
            isUnlocked: count >= 100, progress: min(1, Double(count) / 100),
            unlockedDate: sortedDate(at: 99, workouts: finishedWorkouts)))
        list.append(Achievement(id: "250_workouts", name: "Iron Veteran", description: "Complete 250 workouts",
            icon: "trophy.fill", tier: .platinum, category: .gym,
            isUnlocked: count >= 250, progress: min(1, Double(count) / 250),
            unlockedDate: sortedDate(at: 249, workouts: finishedWorkouts)))

        let streak = Workout.currentStreak(from: inputs.allWorkouts, cardioSessions: inputs.cardioSessions)
        list.append(Achievement(id: "streak_3", name: "Hat Trick", description: "3-day workout streak",
            icon: "bolt", tier: .bronze, category: .gym,
            isUnlocked: streak >= 3, progress: min(1, Double(streak) / 3),
            unlockedDate: streak >= 3 ? .now : nil))
        list.append(Achievement(id: "streak_7", name: "Full Week", description: "7-day workout streak",
            icon: "bolt.fill", tier: .silver, category: .gym,
            isUnlocked: streak >= 7, progress: min(1, Double(streak) / 7),
            unlockedDate: streak >= 7 ? .now : nil))
        list.append(Achievement(id: "streak_30", name: "Monthly Monster", description: "30-day workout streak",
            icon: "bolt.shield", tier: .gold, category: .gym,
            isUnlocked: streak >= 30, progress: min(1, Double(streak) / 30),
            unlockedDate: streak >= 30 ? .now : nil))

        let maxWeight = finishedWorkouts.flatMap { $0.exercises.flatMap(\.sets) }.map(\.weight).max() ?? 0
        list.append(Achievement(id: "lift_100kg", name: "Triple Digits", description: "Lift 100kg / 225lbs on any exercise",
            icon: "scalemass", tier: .silver, category: .gym,
            isUnlocked: maxWeight >= 100, unlockedDate: maxWeight >= 100 ? .now : nil))
        list.append(Achievement(id: "lift_140kg", name: "Three Plates", description: "Lift 140kg / 315lbs on any exercise",
            icon: "scalemass.fill", tier: .gold, category: .gym,
            isUnlocked: maxWeight >= 140, unlockedDate: maxWeight >= 140 ? .now : nil))
        list.append(Achievement(id: "lift_180kg", name: "Four Plates", description: "Lift 180kg / 405lbs on any exercise",
            icon: "crown", tier: .platinum, category: .gym,
            isUnlocked: maxWeight >= 180, unlockedDate: maxWeight >= 180 ? .now : nil))

        let uniqueExercises = Set(finishedWorkouts.flatMap { $0.exercises.map { $0.name.lowercased() } }).count
        list.append(Achievement(id: "variety_10", name: "Variety Pack", description: "Use 10 different exercises",
            icon: "square.grid.3x3", tier: .bronze, category: .gym,
            isUnlocked: uniqueExercises >= 10, progress: min(1, Double(uniqueExercises) / 10),
            unlockedDate: uniqueExercises >= 10 ? .now : nil))
        list.append(Achievement(id: "variety_25", name: "Exercise Explorer", description: "Use 25 different exercises",
            icon: "map", tier: .silver, category: .gym,
            isUnlocked: uniqueExercises >= 25, progress: min(1, Double(uniqueExercises) / 25),
            unlockedDate: uniqueExercises >= 25 ? .now : nil))

        let totalSets = finishedWorkouts.flatMap { $0.exercises.flatMap(\.sets) }.filter { !$0.isWarmUp && !$0.isCardio }.count
        list.append(Achievement(id: "sets_500", name: "Set Machine", description: "Complete 500 total sets",
            icon: "repeat.circle", tier: .silver, category: .gym,
            isUnlocked: totalSets >= 500, progress: min(1, Double(totalSets) / 500),
            unlockedDate: totalSets >= 500 ? .now : nil))
        list.append(Achievement(id: "sets_2000", name: "Volume King", description: "Complete 2,000 total sets",
            icon: "crown.fill", tier: .gold, category: .gym,
            isUnlocked: totalSets >= 2000, progress: min(1, Double(totalSets) / 2000),
            unlockedDate: totalSets >= 2000 ? .now : nil))

        list.append(Achievement(id: "track_weight", name: "Scale Warrior", description: "Log your body weight 10 times",
            icon: "chart.line.uptrend.xyaxis", tier: .bronze, category: .gym,
            isUnlocked: inputs.bodyWeights.count >= 10, progress: min(1, Double(inputs.bodyWeights.count) / 10),
            unlockedDate: inputs.bodyWeights.count >= 10 ? .now : nil))

        let earlyWorkouts = finishedWorkouts.filter {
            let hour = Calendar.current.component(.hour, from: $0.date); return hour >= 5 && hour < 8
        }.count
        list.append(Achievement(id: "early_bird", name: "Early Bird", description: "Complete 10 workouts before 8 AM",
            icon: "sunrise.fill", tier: .silver, category: .gym,
            isUnlocked: earlyWorkouts >= 10, progress: min(1, Double(earlyWorkouts) / 10),
            unlockedDate: earlyWorkouts >= 10 ? .now : nil))

        return list
    }

    // MARK: - Running

    private static func runningAchievements(from inputs: Inputs) -> [Achievement] {
        var list: [Achievement] = []
        let runs = inputs.externalWorkouts.filter { $0.workoutType == .running }
        let runCount = runs.count
        let manualRunSets = inputs.finishedWorkouts
            .flatMap { $0.exercises.filter { $0.category == .cardio } }
            .flatMap(\.sets).filter { $0.isCardio && $0.distance != nil }
        let totalRunCount = runCount + manualRunSets.count
        let externalKm = runs.compactMap(\.totalDistance).reduce(0, +) / 1000
        let manualKm = manualRunSets.compactMap(\.distance).reduce(0, +)
        let totalKm = externalKm + manualKm

        list.append(Achievement(id: "first_run", name: "Off the Mark", description: "Complete your first run",
            icon: "figure.run", tier: .bronze, category: .running,
            isUnlocked: totalRunCount >= 1, progress: min(1, Double(totalRunCount) / 1),
            unlockedDate: totalRunCount >= 1 ? runs.first?.startDate : nil))
        list.append(Achievement(id: "10_runs", name: "Regular Runner", description: "Complete 10 runs",
            icon: "figure.run", tier: .bronze, category: .running,
            isUnlocked: totalRunCount >= 10, progress: min(1, Double(totalRunCount) / 10)))
        list.append(Achievement(id: "50_runs", name: "Dedicated Pacer", description: "Complete 50 runs",
            icon: "figure.run.circle", tier: .silver, category: .running,
            isUnlocked: totalRunCount >= 50, progress: min(1, Double(totalRunCount) / 50)))
        list.append(Achievement(id: "100_runs", name: "Road Warrior", description: "Complete 100 runs",
            icon: "figure.run.circle.fill", tier: .gold, category: .running,
            isUnlocked: totalRunCount >= 100, progress: min(1, Double(totalRunCount) / 100)))

        list.append(Achievement(id: "distance_10k", name: "First 10K", description: "Run a total of 10 km",
            icon: "map", tier: .bronze, category: .running,
            isUnlocked: totalKm >= 10, progress: min(1, totalKm / 10)))
        list.append(Achievement(id: "distance_42k", name: "Marathon Distance", description: "Run a total of 42.2 km",
            icon: "medal", tier: .silver, category: .running,
            isUnlocked: totalKm >= 42.2, progress: min(1, totalKm / 42.2)))
        list.append(Achievement(id: "distance_100k", name: "Ultra Runner", description: "Run a total of 100 km",
            icon: "medal.fill", tier: .gold, category: .running,
            isUnlocked: totalKm >= 100, progress: min(1, totalKm / 100)))
        list.append(Achievement(id: "distance_500k", name: "Iron Legs", description: "Run a total of 500 km",
            icon: "crown.fill", tier: .platinum, category: .running,
            isUnlocked: totalKm >= 500, progress: min(1, totalKm / 500)))

        let longestRunKm = max(
            runs.compactMap(\.totalDistance).max().map { $0 / 1000 } ?? 0,
            manualRunSets.compactMap(\.distance).max() ?? 0
        )
        list.append(Achievement(id: "single_5k", name: "5K Finisher", description: "Complete a single 5 km run",
            icon: "flag", tier: .bronze, category: .running,
            isUnlocked: longestRunKm >= 5, progress: min(1, longestRunKm / 5)))
        list.append(Achievement(id: "single_10k", name: "10K Finisher", description: "Complete a single 10 km run",
            icon: "flag.fill", tier: .silver, category: .running,
            isUnlocked: longestRunKm >= 10, progress: min(1, longestRunKm / 10)))
        list.append(Achievement(id: "single_half", name: "Half Marathon", description: "Complete a single 21.1 km run",
            icon: "flag.checkered", tier: .gold, category: .running,
            isUnlocked: longestRunKm >= 21.1, progress: min(1, longestRunKm / 21.1)))

        return list
    }

    // MARK: - Steps

    private static func stepsAchievements(from inputs: Inputs) -> [Achievement] {
        var list: [Achievement] = []
        let stepsData = inputs.stepsData
        let goalDays = stepsData.filter { $0.steps >= 10_000 }
        let bestDay = stepsData.map(\.steps).max() ?? 0
        let totalSteps = stepsData.map(\.steps).reduce(0, +)

        list.append(Achievement(id: "steps_first_10k", name: "10K Day", description: "Reach 10,000 steps in a day",
            icon: "figure.walk", tier: .bronze, category: .steps,
            isUnlocked: bestDay >= 10_000, progress: min(1, bestDay / 10_000)))
        list.append(Achievement(id: "steps_15k", name: "Extra Mile", description: "Reach 15,000 steps in a day",
            icon: "figure.walk.motion", tier: .silver, category: .steps,
            isUnlocked: bestDay >= 15_000, progress: min(1, bestDay / 15_000)))
        list.append(Achievement(id: "steps_20k", name: "Marathon Walker", description: "Reach 20,000 steps in a day",
            icon: "figure.walk.diamond", tier: .gold, category: .steps,
            isUnlocked: bestDay >= 20_000, progress: min(1, bestDay / 20_000)))
        list.append(Achievement(id: "steps_30k", name: "Unstoppable", description: "Reach 30,000 steps in a day",
            icon: "figure.walk.diamond.fill", tier: .platinum, category: .steps,
            isUnlocked: bestDay >= 30_000, progress: min(1, bestDay / 30_000)))
        list.append(Achievement(id: "steps_goal_7", name: "Week Warrior", description: "Hit 10K steps for 7 days",
            icon: "calendar", tier: .bronze, category: .steps,
            isUnlocked: goalDays.count >= 7, progress: min(1, Double(goalDays.count) / 7)))
        list.append(Achievement(id: "steps_goal_30", name: "Monthly Mover", description: "Hit 10K steps for 30 days",
            icon: "calendar.badge.checkmark", tier: .silver, category: .steps,
            isUnlocked: goalDays.count >= 30, progress: min(1, Double(goalDays.count) / 30)))
        list.append(Achievement(id: "steps_total_100k", name: "Hundred Thousand", description: "Walk 100,000 total steps",
            icon: "shoeprints.fill", tier: .bronze, category: .steps,
            isUnlocked: totalSteps >= 100_000, progress: min(1, totalSteps / 100_000)))
        list.append(Achievement(id: "steps_total_1m", name: "Million Steps", description: "Walk 1,000,000 total steps",
            icon: "star.circle", tier: .gold, category: .steps,
            isUnlocked: totalSteps >= 1_000_000, progress: min(1, totalSteps / 1_000_000)))

        let stepStreak = computeStepStreak(stepsData: stepsData)
        list.append(Achievement(id: "step_streak_7", name: "Step Streak", description: "7-day streak of 10K+ steps",
            icon: "flame", tier: .silver, category: .steps,
            isUnlocked: stepStreak >= 7, progress: min(1, Double(stepStreak) / 7)))
        list.append(Achievement(id: "step_streak_30", name: "Step Legend", description: "30-day streak of 10K+ steps",
            icon: "flame.fill", tier: .platinum, category: .steps,
            isUnlocked: stepStreak >= 30, progress: min(1, Double(stepStreak) / 30)))

        return list
    }

    // MARK: - Sleep

    private static func sleepAchievements(from inputs: Inputs) -> [Achievement] {
        var list: [Achievement] = []
        let sleepData = inputs.sleepData
        let goodNights = sleepData.filter { $0.minutes >= 420 }
        let greatNights = sleepData.filter { $0.minutes >= 480 }
        let trackedNights = sleepData.filter { $0.minutes > 0 }
        let bestNight = sleepData.map(\.minutes).max() ?? 0

        list.append(Achievement(id: "sleep_7h", name: "Well Rested", description: "Get 7+ hours of sleep in a night",
            icon: "moon.fill", tier: .bronze, category: .sleep,
            isUnlocked: bestNight >= 420, progress: min(1, bestNight / 420)))
        list.append(Achievement(id: "sleep_8h", name: "Full Recovery", description: "Get 8+ hours of sleep in a night",
            icon: "moon.stars.fill", tier: .silver, category: .sleep,
            isUnlocked: bestNight >= 480, progress: min(1, bestNight / 480)))
        list.append(Achievement(id: "sleep_9h", name: "Sleep Champion", description: "Get 9+ hours of sleep in a night",
            icon: "moon.zzz.fill", tier: .gold, category: .sleep,
            isUnlocked: bestNight >= 540, progress: min(1, bestNight / 540)))
        list.append(Achievement(id: "sleep_good_7", name: "Sleep Week", description: "Get 7+ hours for 7 nights",
            icon: "bed.double", tier: .bronze, category: .sleep,
            isUnlocked: goodNights.count >= 7, progress: min(1, Double(goodNights.count) / 7)))
        list.append(Achievement(id: "sleep_good_30", name: "Sleep Month", description: "Get 7+ hours for 30 nights",
            icon: "bed.double.fill", tier: .silver, category: .sleep,
            isUnlocked: goodNights.count >= 30, progress: min(1, Double(goodNights.count) / 30)))
        list.append(Achievement(id: "sleep_great_14", name: "Recovery Pro", description: "Get 8+ hours for 14 nights",
            icon: "sparkles", tier: .gold, category: .sleep,
            isUnlocked: greatNights.count >= 14, progress: min(1, Double(greatNights.count) / 14)))

        let sleepStreak = computeSleepStreak(sleepData: sleepData)
        list.append(Achievement(id: "sleep_streak_5", name: "Consistent Sleeper", description: "5-night streak of 7+ hours",
            icon: "bolt.fill", tier: .silver, category: .sleep,
            isUnlocked: sleepStreak >= 5, progress: min(1, Double(sleepStreak) / 5)))
        list.append(Achievement(id: "sleep_streak_14", name: "Sleep Master", description: "14-night streak of 7+ hours",
            icon: "bolt.shield.fill", tier: .gold, category: .sleep,
            isUnlocked: sleepStreak >= 14, progress: min(1, Double(sleepStreak) / 14)))
        list.append(Achievement(id: "sleep_streak_30", name: "Sleep Legend", description: "30-night streak of 7+ hours",
            icon: "crown.fill", tier: .platinum, category: .sleep,
            isUnlocked: sleepStreak >= 30, progress: min(1, Double(sleepStreak) / 30)))
        list.append(Achievement(id: "sleep_tracked_30", name: "Sleep Tracker", description: "Track 30 nights of sleep",
            icon: "chart.bar.fill", tier: .bronze, category: .sleep,
            isUnlocked: trackedNights.count >= 30, progress: min(1, Double(trackedNights.count) / 30)))

        return list
    }

    // MARK: - Helpers

    private static func sortedDate(at index: Int, workouts: [Workout]) -> Date? {
        let sorted = workouts.sorted { $0.date < $1.date }
        guard index < sorted.count else { return nil }
        return sorted[index].date
    }

    private static func computeStepStreak(stepsData: [(date: Date, steps: Double)]) -> Int {
        let sorted = stepsData.sorted { $0.date > $1.date }
        var streak = 0
        for entry in sorted {
            if entry.steps >= 10_000 { streak += 1 } else if entry.steps > 0 { break }
        }
        return streak
    }

    private static func computeSleepStreak(sleepData: [(date: Date, minutes: Double)]) -> Int {
        let sorted = sleepData.sorted { $0.date > $1.date }
        var streak = 0
        for entry in sorted {
            if entry.minutes >= 420 { streak += 1 } else if entry.minutes > 0 { break }
        }
        return streak
    }
}
