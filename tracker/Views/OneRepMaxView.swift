import SwiftUI
import SwiftData

struct OneRepMaxView: View {
    @Query(filter: #Predicate<Workout> { !$0.isTemplate && $0.endTime != nil },
           sort: \Workout.date)
    private var workouts: [Workout]
    @Environment(\.weightUnit) private var unit

    @State private var selectedExercise: String?
    @State private var formula: OneRepMaxEngine.Formula = .epley

    private var exerciseNames: [String] { OneRepMaxEngine.exerciseNames(from: workouts) }

    private var e1rmHistory: [(Date, Double)] {
        guard let name = selectedExercise else { return [] }
        return OneRepMaxEngine.e1rmHistory(workouts: workouts, exerciseName: name, formula: formula)
    }

    private var currentE1RM: Double { e1rmHistory.last?.1 ?? 0 }
    private var peakE1RM: Double { e1rmHistory.map(\.1).max() ?? 0 }
    private var percentageRows: [(label: String, value: Double)] {
        OneRepMaxEngine.percentageRows(base: currentE1RM)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                OneRepMaxSections.exercisePickerCard(
                    exerciseNames: exerciseNames,
                    selectedExercise: $selectedExercise
                )

                if selectedExercise != nil && !e1rmHistory.isEmpty {
                    OneRepMaxSections.heroCard(
                        exerciseName: selectedExercise ?? "",
                        currentE1RM: currentE1RM,
                        peakE1RM: peakE1RM,
                        sessionCount: e1rmHistory.count,
                        weightUnit: unit
                    )
                    OneRepMaxSections.chartCard(e1rmHistory: e1rmHistory, weightUnit: unit)
                    OneRepMaxSections.formulaCard(formula: $formula)
                    OneRepMaxSections.percentageCard(percentageRows: percentageRows, weightUnit: unit)
                } else if selectedExercise != nil {
                    OneRepMaxSections.emptyExerciseCard()
                } else if exerciseNames.isEmpty {
                    OneRepMaxSections.noDataCard()
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Estimated 1RM")
        .onAppear {
            if selectedExercise == nil { selectedExercise = exerciseNames.first }
        }
    }
}

#Preview {
    NavigationStack { OneRepMaxView() }
        .modelContainer(for: Workout.self, inMemory: true)
}
