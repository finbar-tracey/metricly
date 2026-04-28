import SwiftUI
import SwiftData
import HealthKit

struct Achievement: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let tier: Tier
    let category: Category
    var isUnlocked: Bool
    var progress: Double?
    var unlockedDate: Date?

    enum Tier: String, CaseIterable {
        case bronze = "Bronze"
        case silver = "Silver"
        case gold = "Gold"
        case platinum = "Platinum"

        var color: Color {
            switch self {
            case .bronze: return .brown
            case .silver: return .gray
            case .gold: return .yellow
            case .platinum: return .cyan
            }
        }
    }

    enum Category: String, CaseIterable {
        case gym = "Gym"
        case running = "Running"
        case steps = "Steps"
        case sleep = "Sleep"

        var icon: String {
            switch self {
            case .gym: return "dumbbell.fill"
            case .running: return "figure.run"
            case .steps: return "figure.walk"
            case .sleep: return "moon.zzz.fill"
            }
        }

        var color: Color {
            switch self {
            case .gym: return .blue
            case .running: return .orange
            case .steps: return .green
            case .sleep: return .indigo
            }
        }
    }
}

struct AchievementsView: View {
    @Query(filter: #Predicate<Workout> { !$0.isTemplate && $0.endTime != nil })
    private var workouts: [Workout]
    @Query private var bodyWeights: [BodyWeightEntry]
    @Environment(\.weightUnit) private var unit

    @State private var selectedCategory: Achievement.Category?
    @State private var sleepData: [(date: Date, minutes: Double)] = []
    @State private var stepsData: [(date: Date, steps: Double)] = []
    @State private var externalWorkouts: [ExternalWorkout] = []
    @State private var isLoading = true

    private var finishedWorkouts: [Workout] { workouts.filter { $0.endTime != nil } }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                heroCard
                categoryPickerCard
                achievementTiersCards
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadHealthData() }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        let all = allAchievements
        let unlocked = all.filter(\.isUnlocked).count
        let total = all.count

        return ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Color(red: 0.78, green: 0.60, blue: 0.08), Color.orange.opacity(0.70)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Circle().fill(.white.opacity(0.07)).frame(width: 200).offset(x: 160, y: -60)

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle().fill(.white.opacity(0.20)).frame(width: 52, height: 52)
                        Image(systemName: "medal.fill")
                            .font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Achievements")
                            .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.75))
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(unlocked)")
                                .font(.system(size: 36, weight: .black, design: .rounded))
                                .foregroundStyle(.white).monospacedDigit()
                            Text("/ \(total)")
                                .font(.title3.weight(.semibold)).foregroundStyle(.white.opacity(0.75))
                        }
                    }
                    Spacer()
                    Text("\(Int(Double(unlocked) / Double(max(1, total)) * 100))%")
                        .font(.caption.bold())
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.white.opacity(0.20), in: Capsule())
                        .foregroundStyle(.white)
                }

                GradientProgressBar(value: Double(unlocked) / Double(max(1, total)), color: .white, height: 6)
                    .opacity(0.80)

                HStack(spacing: 0) {
                    ForEach(Achievement.Category.allCases, id: \.self) { cat in
                        let catAll = all.filter { $0.category == cat }
                        let catUnlocked = catAll.filter(\.isUnlocked).count
                        VStack(spacing: 4) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.85))
                            Text("\(catUnlocked)/\(catAll.count)")
                                .font(.caption2.bold().monospacedDigit())
                                .foregroundStyle(.white.opacity(0.70))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(20)
        }
        .heroCard()
    }

    // MARK: - Category Picker Card

    private var categoryPickerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Category", icon: "tag.fill", color: .accentColor)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(label: "All", icon: "medal.fill", color: .yellow, isSelected: selectedCategory == nil) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedCategory = nil }
                    }
                    ForEach(Achievement.Category.allCases, id: \.self) { cat in
                        filterChip(label: cat.rawValue, icon: cat.icon, color: cat.color, isSelected: selectedCategory == cat) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedCategory = cat }
                        }
                    }
                }
            }
        }
        .appCard()
    }

    private func filterChip(label: String, icon: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.caption2)
                Text(label).font(.caption.bold())
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(isSelected ? color : Color(.secondarySystemFill), in: Capsule())
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Achievement Tier Cards

    @ViewBuilder
    private var achievementTiersCards: some View {
        let filtered = filteredAchievements
        ForEach(Achievement.Tier.allCases, id: \.self) { tier in
            let tierItems = filtered.filter { $0.tier == tier }
            if !tierItems.isEmpty {
                tierCard(tier: tier, items: tierItems)
            }
        }
    }

    private func tierCard(tier: Achievement.Tier, items: [Achievement]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(tier.color.opacity(0.15)).frame(width: 28, height: 28)
                    Image(systemName: "medal.fill")
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(tier.color)
                }
                Text(tier.rawValue.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                let unlockedCount = items.filter(\.isUnlocked).count
                Text("\(unlockedCount)/\(items.count)")
                    .font(.caption2.bold().monospacedDigit()).foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, achievement in
                    achievementRow(achievement)
                    if idx < items.count - 1 { Divider().padding(.leading, 62) }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    // MARK: - Achievement Row

    private func achievementRow(_ achievement: Achievement) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? achievement.tier.color.opacity(0.20) : Color(.systemFill))
                    .frame(width: 44, height: 44)
                Image(systemName: achievement.icon)
                    .font(.title3)
                    .foregroundStyle(achievement.isUnlocked ? achievement.tier.color : Color.secondary.opacity(0.4))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(achievement.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(achievement.isUnlocked ? .primary : .secondary)
                    Image(systemName: achievement.category.icon)
                        .font(.caption2).foregroundStyle(achievement.category.color)
                }
                Text(achievement.description)
                    .font(.caption).foregroundStyle(.secondary)
                if let date = achievement.unlockedDate, achievement.isUnlocked {
                    Text(date, format: .dateTime.month(.abbreviated).day().year())
                        .font(.caption2).foregroundStyle(.tertiary)
                } else if let progress = achievement.progress, !achievement.isUnlocked {
                    HStack(spacing: 6) {
                        GradientProgressBar(value: progress, color: achievement.category.color, height: 4)
                            .frame(maxWidth: 120)
                        Text("\(Int(progress * 100))%")
                            .font(.caption2.bold().monospacedDigit())
                            .foregroundStyle(achievement.category.color)
                    }
                }
            }

            Spacer()

            if achievement.isUnlocked {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Image(systemName: "lock.fill").foregroundStyle(.tertiary)
            }
        }
        .opacity(achievement.isUnlocked ? 1.0 : 0.65)
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    // MARK: - Computed

    private var allAchievements: [Achievement] {
        gymAchievements + runningAchievements + stepsAchievements + sleepAchievements
    }

    private var filteredAchievements: [Achievement] {
        guard let cat = selectedCategory else { return allAchievements }
        return allAchievements.filter { $0.category == cat }
    }

    // MARK: - Gym Achievements

    private var gymAchievements: [Achievement] {
        var list: [Achievement] = []
        let count = finishedWorkouts.count

        list.append(Achievement(id: "first_workout", name: "First Step", description: "Complete your first workout",
            icon: "figure.strengthtraining.traditional", tier: .bronze, category: .gym,
            isUnlocked: count >= 1, progress: min(1, Double(count) / 1),
            unlockedDate: count >= 1 ? sortedDate(at: 0) : nil))
        list.append(Achievement(id: "ten_workouts", name: "Getting Serious", description: "Complete 10 workouts",
            icon: "flame", tier: .bronze, category: .gym,
            isUnlocked: count >= 10, progress: min(1, Double(count) / 10),
            unlockedDate: sortedDate(at: 9)))
        list.append(Achievement(id: "25_workouts", name: "Quarter Century", description: "Complete 25 workouts",
            icon: "star", tier: .silver, category: .gym,
            isUnlocked: count >= 25, progress: min(1, Double(count) / 25),
            unlockedDate: sortedDate(at: 24)))
        list.append(Achievement(id: "50_workouts", name: "Half Century", description: "Complete 50 workouts",
            icon: "star.fill", tier: .silver, category: .gym,
            isUnlocked: count >= 50, progress: min(1, Double(count) / 50),
            unlockedDate: sortedDate(at: 49)))
        list.append(Achievement(id: "100_workouts", name: "Century Club", description: "Complete 100 workouts",
            icon: "trophy", tier: .gold, category: .gym,
            isUnlocked: count >= 100, progress: min(1, Double(count) / 100),
            unlockedDate: sortedDate(at: 99)))
        list.append(Achievement(id: "250_workouts", name: "Iron Veteran", description: "Complete 250 workouts",
            icon: "trophy.fill", tier: .platinum, category: .gym,
            isUnlocked: count >= 250, progress: min(1, Double(count) / 250),
            unlockedDate: sortedDate(at: 249)))

        let streak = currentStreak
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

        let maxWeight = allTimeMaxWeight
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
            isUnlocked: bodyWeights.count >= 10, progress: min(1, Double(bodyWeights.count) / 10),
            unlockedDate: bodyWeights.count >= 10 ? .now : nil))

        let earlyWorkouts = finishedWorkouts.filter {
            let hour = Calendar.current.component(.hour, from: $0.date); return hour >= 5 && hour < 8
        }.count
        list.append(Achievement(id: "early_bird", name: "Early Bird", description: "Complete 10 workouts before 8 AM",
            icon: "sunrise.fill", tier: .silver, category: .gym,
            isUnlocked: earlyWorkouts >= 10, progress: min(1, Double(earlyWorkouts) / 10),
            unlockedDate: earlyWorkouts >= 10 ? .now : nil))

        return list
    }

    // MARK: - Running Achievements

    private var runningAchievements: [Achievement] {
        var list: [Achievement] = []
        let runs = externalWorkouts.filter { $0.workoutType == .running }
        let runCount = runs.count
        let manualRunSets = finishedWorkouts
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

    // MARK: - Steps Achievements

    private var stepsAchievements: [Achievement] {
        var list: [Achievement] = []
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

        let stepStreak = computeStepStreak()
        list.append(Achievement(id: "step_streak_7", name: "Step Streak", description: "7-day streak of 10K+ steps",
            icon: "flame", tier: .silver, category: .steps,
            isUnlocked: stepStreak >= 7, progress: min(1, Double(stepStreak) / 7)))
        list.append(Achievement(id: "step_streak_30", name: "Step Legend", description: "30-day streak of 10K+ steps",
            icon: "flame.fill", tier: .platinum, category: .steps,
            isUnlocked: stepStreak >= 30, progress: min(1, Double(stepStreak) / 30)))

        return list
    }

    // MARK: - Sleep Achievements

    private var sleepAchievements: [Achievement] {
        var list: [Achievement] = []
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

        let sleepStreak = computeSleepStreak()
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

    // MARK: - Gym Computed Properties

    private var currentStreak: Int {
        let calendar = Calendar.current
        let dates = Set(finishedWorkouts.map { calendar.startOfDay(for: $0.date) })
        var streak = 0; var day = calendar.startOfDay(for: .now)
        while dates.contains(day) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }

    private var allTimeMaxWeight: Double {
        finishedWorkouts.flatMap { $0.exercises.flatMap(\.sets) }.map(\.weight).max() ?? 0
    }

    private func sortedDate(at index: Int) -> Date? {
        let sorted = finishedWorkouts.sorted { $0.date < $1.date }
        guard index < sorted.count else { return nil }
        return sorted[index].date
    }

    private func computeStepStreak() -> Int {
        let sorted = stepsData.sorted { $0.date > $1.date }
        var streak = 0
        for entry in sorted {
            if entry.steps >= 10_000 { streak += 1 } else if entry.steps > 0 { break }
        }
        return streak
    }

    private func computeSleepStreak() -> Int {
        let sorted = sleepData.sorted { $0.date > $1.date }
        var streak = 0
        for entry in sorted {
            if entry.minutes >= 420 { streak += 1 } else if entry.minutes > 0 { break }
        }
        return streak
    }

    // MARK: - Data Loading

    private func loadHealthData() async {
        isLoading = true
        defer { isLoading = false }
        let hk = HealthKitManager.shared
        async let steps = hk.fetchDailySteps(days: 90)
        async let sleep = hk.fetchDailySleep(days: 90)
        async let external = hk.fetchExternalWorkouts(days: 365)
        stepsData = (try? await steps) ?? []
        sleepData = (try? await sleep) ?? []
        externalWorkouts = (try? await external) ?? []
    }
}

#Preview {
    NavigationStack { AchievementsView() }
        .modelContainer(for: Workout.self, inMemory: true)
}
