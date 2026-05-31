import SwiftUI
import SwiftData

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
    @Environment(\.appServices) private var appServices
    @Query(filter: #Predicate<Workout> { !$0.isTemplate && $0.endTime != nil })
    private var workouts: [Workout]
    @Query private var cardioSessions: [CardioSession]
    @Query private var bodyWeights: [BodyWeightEntry]

    @State private var selectedCategory: Achievement.Category?
    @State private var sleepData: [(date: Date, minutes: Double)] = []
    @State private var stepsData: [(date: Date, steps: Double)] = []
    @State private var externalWorkouts: [ExternalWorkout] = []

    @AppStorage("achievements.celebrated") private var celebratedRaw = ""
    @AppStorage("achievements.celebrationInit") private var celebrationBaselined = false
    @AppStorage("celebrationsEnabled") private var celebrationsEnabled = true
    @State private var celebrationQueue: [Achievement] = []
    @State private var celebrating: Achievement?

    private var finishedWorkouts: [Workout] { workouts }

    private var allAchievements: [Achievement] {
        AchievementsEngine.allAchievements(from: .init(
            finishedWorkouts: finishedWorkouts,
            allWorkouts: workouts,
            cardioSessions: cardioSessions,
            bodyWeights: bodyWeights,
            stepsData: stepsData,
            sleepData: sleepData,
            externalWorkouts: externalWorkouts
        ))
    }

    private var filteredAchievements: [Achievement] {
        guard let cat = selectedCategory else { return allAchievements }
        return allAchievements.filter { $0.category == cat }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                AchievementsHeroSection.heroCard(allAchievements: allAchievements)
                AchievementsGridSection.almostThereCard(
                    allAchievements: allAchievements,
                    selectedCategory: $selectedCategory
                )
                AchievementsHeroSection.categoryPickerCard(selectedCategory: $selectedCategory)
                AchievementsGridSection.achievementTiersCards(filteredAchievements: filteredAchievements)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            AchievementsHeroSection.celebrationOverlay(celebrating: celebrating, onTap: advanceCelebration)
        }
        .task {
            await loadHealthData()
            checkForNewUnlocks()
        }
    }

    // MARK: - Unlock celebration

    private var celebratedIDs: Set<String> {
        Set(celebratedRaw.split(separator: ",").map(String.init))
    }

    private func checkForNewUnlocks() {
        let unlockedIDs = Set(allAchievements.filter { $0.isUnlocked }.map(\.id))
        if !celebrationBaselined {
            celebratedRaw = unlockedIDs.sorted().joined(separator: ",")
            celebrationBaselined = true
            return
        }
        let newly = allAchievements.filter { $0.isUnlocked && !celebratedIDs.contains($0.id) }
        guard !newly.isEmpty else { return }
        celebratedRaw = celebratedIDs.union(unlockedIDs).sorted().joined(separator: ",")
        guard celebrationsEnabled else { return }
        celebrationQueue = newly
        advanceCelebration()
    }

    private func advanceCelebration() {
        guard !celebrationQueue.isEmpty else {
            withAnimation(.easeOut(duration: 0.35)) { celebrating = nil }
            return
        }
        let next = celebrationQueue.removeFirst()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.62)) { celebrating = next }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            if celebrating?.id == next.id { advanceCelebration() }
        }
    }

    // MARK: - Data Loading

    private func loadHealthData() async {
        let hk = appServices.healthDataCache
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
