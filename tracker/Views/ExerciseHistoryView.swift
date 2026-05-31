import SwiftUI
import SwiftData

struct ExerciseHistoryView: View {
    @Environment(\.weightUnit) private var weightUnit
    @Query private var allExercises: [Exercise]
    let exerciseName: String

    init(exerciseName: String) {
        self.exerciseName = exerciseName
        _allExercises = Query(filter: #Predicate<Exercise> { $0.name == exerciseName })
    }

    @State private var showEstimated1RM = false
    @State private var sortOrder: HistorySortOrder = .date
    @State private var cardioSortOrder: CardioSortOrder = .date

    private enum HistorySortOrder: String, CaseIterable {
        case date = "Date"
        case weight = "Weight"
        case reps = "Reps"
    }

    private enum CardioSortOrder: String, CaseIterable {
        case date = "Date"
        case distance = "Distance"
        case duration = "Duration"
    }

    private var history: [Exercise] {
        allExercises
            .filter { $0.name == exerciseName && !(($0.workout?.isTemplate) ?? true) && !$0.sets.isEmpty }
            .sorted { ($0.workout?.date ?? .distantPast) > ($1.workout?.date ?? .distantPast) }
    }

    private var isCardioExercise: Bool { history.first?.category == .cardio }
    private var distanceUnit: DistanceUnit { weightUnit.distanceUnit }

    private var sortedHistory: [Exercise] {
        if isCardioExercise {
            switch cardioSortOrder {
            case .date: return history
            case .distance: return history.sorted { ($0.sets.compactMap(\.distance).max() ?? 0) > ($1.sets.compactMap(\.distance).max() ?? 0) }
            case .duration: return history.sorted { ($0.sets.compactMap(\.durationSeconds).max() ?? 0) > ($1.sets.compactMap(\.durationSeconds).max() ?? 0) }
            }
        } else {
            switch sortOrder {
            case .date: return history
            case .weight: return history.sorted { ($0.sets.map(\.weight).max() ?? 0) > ($1.sets.map(\.weight).max() ?? 0) }
            case .reps: return history.sorted { ($0.sets.map(\.reps).max() ?? 0) > ($1.sets.map(\.reps).max() ?? 0) }
            }
        }
    }

    private var bestSet: ExerciseSet? {
        let allSets = history.flatMap(\.sets)
        if isCardioExercise { return allSets.max { ($0.distance ?? 0) < ($1.distance ?? 0) } }
        return allSets.max { $0.weight < $1.weight }
    }

    private var progressionRecommendation: ProgressionRecommendation? {
        guard !isCardioExercise else { return nil }
        let sessions = ProgressionAdvisor.buildSessions(from: history)
        guard sessions.count >= 2 else { return nil }
        let rec = ProgressionAdvisor.recommend(sessions: sessions, muscleGroup: history.first?.category)
        if case .insufficient = rec.action { return nil }
        return rec
    }

    private var chartData: [ExerciseHistorySections.ChartPoint] {
        ExerciseHistorySections.chartData(from: history)
    }

    private var cardioChartData: [ExerciseHistorySections.CardioChartPoint] {
        ExerciseHistorySections.cardioChartData(from: history)
    }

    private var currentEstimated1RM: Double? { chartData.last?.estimated1RM }

    var body: some View {
        List {
            ExerciseGuideSectionView(exerciseName: exerciseName)

            if let rec = progressionRecommendation {
                Section { ProgressionBannerView(recommendation: rec) }
            }

            if let best = bestSet {
                Section {
                    ExerciseHistorySections.bestSetCard(
                        best: best,
                        isCardioExercise: isCardioExercise,
                        weightUnit: weightUnit,
                        distanceUnit: distanceUnit,
                        estimated1RM: currentEstimated1RM
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }

            if isCardioExercise {
                if cardioChartData.count >= 2 {
                    Section {
                        ExerciseHistorySections.cardioProgressionChart(
                            cardioChartData: cardioChartData,
                            distanceUnit: distanceUnit,
                            chartYDomain: ExerciseHistorySections.cardioChartYDomain(
                                cardioChartData: cardioChartData,
                                distanceUnit: distanceUnit
                            )
                        )
                        .frame(height: 200).padding(.vertical, 8)
                    } header: { Text("Progression") }
                }
            } else {
                if chartData.count >= 2 {
                    Section {
                        HStack(spacing: 6) {
                            ExerciseHistorySections.chartToggle("Max Weight", value: false, showEstimated1RM: $showEstimated1RM)
                            ExerciseHistorySections.chartToggle("Est. 1RM", value: true, showEstimated1RM: $showEstimated1RM)
                            Spacer()
                        }
                        .listRowSeparator(.hidden)
                        ExerciseHistorySections.progressionChart(
                            chartData: chartData,
                            showEstimated1RM: showEstimated1RM,
                            weightUnit: weightUnit,
                            chartYDomain: ExerciseHistorySections.chartYDomain(
                                chartData: chartData,
                                showEstimated1RM: showEstimated1RM,
                                weightUnit: weightUnit
                            )
                        )
                        .frame(height: 200).padding(.vertical, 8)
                    } header: { Text("Progression") }
                }
            }

            Section {
                if history.isEmpty {
                    Text("No history yet for this exercise.").foregroundStyle(.secondary)
                } else {
                    ForEach(sortedHistory.prefix(10)) { exercise in
                        VStack(alignment: .leading, spacing: 6) {
                            if let date = exercise.workout?.date {
                                Text(date, format: .dateTime.weekday(.wide).month().day())
                                    .font(.subheadline.weight(.semibold))
                            }
                            if isCardioExercise {
                                ExerciseHistorySections.cardioSessionSets(exercise.sets, distanceUnit: distanceUnit)
                            } else {
                                ExerciseHistorySections.strengthSessionSets(exercise.sets, weightUnit: weightUnit)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                HStack {
                    Text("Recent Sessions")
                    Spacer()
                    if isCardioExercise {
                        Menu {
                            Picker("Sort", selection: $cardioSortOrder) {
                                ForEach(CardioSortOrder.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                            }
                        } label: {
                            Label("Sort", systemImage: "arrow.up.arrow.down").font(.caption).textCase(nil)
                        }
                    } else {
                        Menu {
                            Picker("Sort", selection: $sortOrder) {
                                ForEach(HistorySortOrder.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                            }
                        } label: {
                            Label("Sort", systemImage: "arrow.up.arrow.down").font(.caption).textCase(nil)
                        }
                    }
                }
            }
        }
        .navigationTitle(exerciseName)
        .navigationDestination(for: FormGuideDestination.self) { dest in
            ExerciseGuideView(exerciseName: dest.exerciseName)
        }
    }
}
