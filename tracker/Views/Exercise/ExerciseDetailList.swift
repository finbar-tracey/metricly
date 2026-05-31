import SwiftUI
import SwiftData

extension ExerciseDetailView {

    @ViewBuilder
    var exerciseDetailList: some View {
        List {
            Section {
                ExerciseHeaderStrip(
                    exercise: exercise,
                    prWeight: historicalBestWeight,
                    activeGoal: liftGoals.first(where: {
                        $0.exerciseName.lowercased() == exercise.name.lowercased() && $0.achievedDate == nil
                    }),
                    weightUnit: weightUnit
                )
                .listRowBackground(Color.clear)
                .listRowInsets(.init(top: 4, leading: 16, bottom: 4, trailing: 16))
            }

            if let hint = exercisePlanHint {
                Section {
                    hint
                        .listRowBackground(Color.clear)
                        .listRowInsets(.init(top: 0, leading: 16, bottom: 4, trailing: 16))
                }
            }

            Section {
                TextField("Add a note...", text: Binding(
                    get: { exercise.notes },
                    set: { exercise.notes = $0 }
                ), axis: .vertical)
                .lineLimit(2...4)
                .font(.subheadline)
                .listRowBackground(Color(.secondarySystemGroupedBackground))
            } header: {
                SectionHeader(title: "Notes", icon: "note.text", color: .blue)
            }

            if exercise.sets.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "repeat")
                            .font(.system(size: 32))
                            .foregroundStyle(.tertiary)
                        Text("No Sets Logged")
                            .font(.subheadline.weight(.semibold))
                        Text("Add a set below to start tracking.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ForEach(Array(exercise.sets.enumerated()), id: \.element.persistentModelID) { index, exerciseSet in
                        ExerciseSetRow(
                            exercise: exercise,
                            index: index,
                            exerciseSet: exerciseSet,
                            session: session,
                            weightUnit: weightUnit,
                            isPR: isPR,
                            warmUpCountBefore: warmUpCountBefore,
                            onDuplicate: { duplicateSet(exerciseSet) }
                        )
                        .listRowBackground(ExerciseSetRowBackground(exerciseSet: exerciseSet, isPR: isPR(exerciseSet)))
                    }
                    .onDelete(perform: deleteSets)
                } header: {
                    ExerciseSetsSectionHeader(
                        workingCount: exercise.sets.filter { !$0.isWarmUp }.count,
                        lastSessionSummary: lastSessionSummaryText
                    )
                }
            }

            ExerciseNewSetSection(
                exercise: exercise,
                session: session,
                weightUnit: weightUnit,
                isCardioExercise: isCardioExercise,
                suggestedSet: suggestedSet,
                isWeightFieldFocused: $isWeightFieldFocused,
                onAddSet: addSet
            )
        }
    }
}
