import SwiftUI
import SwiftData

struct Achievement: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let tier: Tier
    var isUnlocked: Bool
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
}

struct AchievementsView: View {
    @Query(filter: #Predicate<Workout> { !$0.isTemplate })
    private var workouts: [Workout]
    @Query private var bodyWeights: [BodyWeightEntry]
    @Environment(\.weightUnit) private var unit

    private var finishedWorkouts: [Workout] {
        workouts.filter { $0.endTime != nil }
    }

    private var achievements: [Achievement] {
        var list: [Achievement] = []

        let count = finishedWorkouts.count

        // Workout count milestones
        list.append(Achievement(
            id: "first_workout", name: "First Step", description: "Complete your first workout",
            icon: "figure.walk", tier: .bronze,
            isUnlocked: count >= 1, unlockedDate: count >= 1 ? finishedWorkouts.sorted(by: { $0.date < $1.date }).first?.date : nil
        ))
        list.append(Achievement(
            id: "ten_workouts", name: "Getting Serious", description: "Complete 10 workouts",
            icon: "flame", tier: .bronze,
            isUnlocked: count >= 10, unlockedDate: sortedDate(at: 9)
        ))
        list.append(Achievement(
            id: "25_workouts", name: "Quarter Century", description: "Complete 25 workouts",
            icon: "star", tier: .silver,
            isUnlocked: count >= 25, unlockedDate: sortedDate(at: 24)
        ))
        list.append(Achievement(
            id: "50_workouts", name: "Half Century", description: "Complete 50 workouts",
            icon: "star.fill", tier: .silver,
            isUnlocked: count >= 50, unlockedDate: sortedDate(at: 49)
        ))
        list.append(Achievement(
            id: "100_workouts", name: "Century Club", description: "Complete 100 workouts",
            icon: "trophy", tier: .gold,
            isUnlocked: count >= 100, unlockedDate: sortedDate(at: 99)
        ))
        list.append(Achievement(
            id: "250_workouts", name: "Iron Veteran", description: "Complete 250 workouts",
            icon: "trophy.fill", tier: .platinum,
            isUnlocked: count >= 250, unlockedDate: sortedDate(at: 249)
        ))

        // Streak achievements
        let streak = currentStreak
        list.append(Achievement(
            id: "streak_3", name: "Hat Trick", description: "3-day workout streak",
            icon: "bolt", tier: .bronze,
            isUnlocked: streak >= 3, unlockedDate: streak >= 3 ? .now : nil
        ))
        list.append(Achievement(
            id: "streak_7", name: "Full Week", description: "7-day workout streak",
            icon: "bolt.fill", tier: .silver,
            isUnlocked: streak >= 7, unlockedDate: streak >= 7 ? .now : nil
        ))
        list.append(Achievement(
            id: "streak_30", name: "Monthly Monster", description: "30-day workout streak",
            icon: "bolt.shield", tier: .gold,
            isUnlocked: streak >= 30, unlockedDate: streak >= 30 ? .now : nil
        ))

        // Weight milestones
        let maxWeight = allTimeMaxWeight
        list.append(Achievement(
            id: "lift_100kg", name: "Triple Digits", description: "Lift 100kg / 225lbs on any exercise",
            icon: "scalemass", tier: .silver,
            isUnlocked: maxWeight >= 100, unlockedDate: maxWeight >= 100 ? .now : nil
        ))
        list.append(Achievement(
            id: "lift_140kg", name: "Three Plates", description: "Lift 140kg / 315lbs on any exercise",
            icon: "scalemass.fill", tier: .gold,
            isUnlocked: maxWeight >= 140, unlockedDate: maxWeight >= 140 ? .now : nil
        ))
        list.append(Achievement(
            id: "lift_180kg", name: "Four Plates", description: "Lift 180kg / 405lbs on any exercise",
            icon: "crown", tier: .platinum,
            isUnlocked: maxWeight >= 180, unlockedDate: maxWeight >= 180 ? .now : nil
        ))

        // Variety achievements
        let uniqueExercises = Set(finishedWorkouts.flatMap { $0.exercises.map(\.name.lowercased) }).count
        list.append(Achievement(
            id: "variety_10", name: "Variety Pack", description: "Use 10 different exercises",
            icon: "square.grid.3x3", tier: .bronze,
            isUnlocked: uniqueExercises >= 10, unlockedDate: uniqueExercises >= 10 ? .now : nil
        ))
        list.append(Achievement(
            id: "variety_25", name: "Exercise Explorer", description: "Use 25 different exercises",
            icon: "map", tier: .silver,
            isUnlocked: uniqueExercises >= 25, unlockedDate: uniqueExercises >= 25 ? .now : nil
        ))

        // Body weight tracking
        list.append(Achievement(
            id: "track_weight", name: "Scale Warrior", description: "Log your body weight 10 times",
            icon: "chart.line.uptrend.xyaxis", tier: .bronze,
            isUnlocked: bodyWeights.count >= 10, unlockedDate: bodyWeights.count >= 10 ? .now : nil
        ))

        // Volume achievements
        let totalSets = finishedWorkouts.flatMap { $0.exercises.flatMap(\.sets) }.count
        list.append(Achievement(
            id: "sets_500", name: "Set Machine", description: "Complete 500 total sets",
            icon: "repeat.circle", tier: .silver,
            isUnlocked: totalSets >= 500, unlockedDate: totalSets >= 500 ? .now : nil
        ))
        list.append(Achievement(
            id: "sets_2000", name: "Volume King", description: "Complete 2,000 total sets",
            icon: "crown.fill", tier: .gold,
            isUnlocked: totalSets >= 2000, unlockedDate: totalSets >= 2000 ? .now : nil
        ))

        return list
    }

    private var currentStreak: Int {
        let calendar = Calendar.current
        let dates = Set(finishedWorkouts.map { calendar.startOfDay(for: $0.date) })
        var streak = 0
        var day = calendar.startOfDay(for: .now)
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

    var body: some View {
        List {
            // Summary
            Section {
                let unlocked = achievements.filter(\.isUnlocked).count
                let total = achievements.count
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "medal.fill")
                            .font(.title)
                            .foregroundStyle(.yellow)
                        VStack(alignment: .leading) {
                            Text("\(unlocked) / \(total)")
                                .font(.title2.bold())
                            Text("Achievements Unlocked")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    ProgressView(value: Double(unlocked), total: Double(total))
                        .tint(.yellow)
                }
                .padding(.vertical, 4)
            }

            // By tier
            ForEach(Achievement.Tier.allCases, id: \.self) { tier in
                let tierAchievements = achievements.filter { $0.tier == tier }
                if !tierAchievements.isEmpty {
                    Section(tier.rawValue) {
                        ForEach(tierAchievements) { achievement in
                            achievementRow(achievement)
                        }
                    }
                }
            }
        }
        .navigationTitle("Achievements")
    }

    private func achievementRow(_ achievement: Achievement) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? achievement.tier.color.opacity(0.2) : .gray.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: achievement.icon)
                    .font(.title3)
                    .foregroundStyle(achievement.isUnlocked ? achievement.tier.color : .gray.opacity(0.4))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(achievement.isUnlocked ? .primary : .secondary)
                Text(achievement.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let date = achievement.unlockedDate, achievement.isUnlocked {
                    Text(date, format: .dateTime.month(.abbreviated).day().year())
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if achievement.isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.gray.opacity(0.4))
            }
        }
        .opacity(achievement.isUnlocked ? 1.0 : 0.6)
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        AchievementsView()
    }
    .modelContainer(for: Workout.self, inMemory: true)
}
