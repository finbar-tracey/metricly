import SwiftUI
import SwiftData

struct EditSetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.weightUnit) private var weightUnit
    @Query private var settingsArray: [UserSettings]
    let exerciseSet: ExerciseSet
    @State private var reps: Int
    @State private var weight: Double
    @FocusState private var isWeightFieldFocused: Bool

    init(exerciseSet: ExerciseSet, reps: Int, weight: Double) {
        self.exerciseSet = exerciseSet
        _reps = State(initialValue: reps)
        _weight = State(initialValue: weight)
    }

    var body: some View {
        NavigationStack {
            Form {
                Stepper("Reps: \(reps)", value: $reps, in: 1...100)
                HStack {
                    Text("Weight (\(weightUnit.label))")
                    Spacer()
                    TextField("Weight", value: $weight, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .focused($isWeightFieldFocused)
                        .onChange(of: weight) {
                            if weight < 0 { weight = 0 }
                        }
                }
            }
            .navigationTitle("Edit Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isWeightFieldFocused = false
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        exerciseSet.reps = reps
                        exerciseSet.weight = weightUnit.toKg(weight)
                        dismiss()
                    }
                }
            }
        }
    }
}
