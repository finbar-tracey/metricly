import SwiftUI
import SwiftData

/// Per-exercise rest-duration override editor. Lets the user set a custom
/// rest interval for this specific exercise (overriding the global default
/// from Settings) and pushes the new map to the Watch immediately so its
/// rest timer respects the change mid-session.
///
/// "Use default" clears the override.
struct ExerciseRestEditorSheet: View {
    let exercise: Exercise
    let defaultGlobal: Int
    let onSave: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allExercises: [Exercise]

    @State private var useCustom: Bool
    @State private var seconds: Int

    init(exercise: Exercise, defaultGlobal: Int, onSave: @escaping () -> Void) {
        self.exercise = exercise
        self.defaultGlobal = defaultGlobal
        self.onSave = onSave
        _useCustom = State(initialValue: exercise.customRestDuration != nil)
        _seconds = State(initialValue: exercise.customRestDuration ?? defaultGlobal)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Custom rest for this exercise", isOn: $useCustom)
                } footer: {
                    Text(useCustom
                         ? "Overrides your default for \(exercise.name) only. The Watch's rest timer respects this value too."
                         : "Uses your global \(defaultGlobal)-second default from Settings.")
                }

                if useCustom {
                    Section {
                        Stepper(value: $seconds, in: 15...600, step: 15) {
                            HStack {
                                Image(systemName: "timer")
                                    .foregroundStyle(Color.accentColor)
                                Text("\(seconds) seconds")
                                    .font(.headline.monospacedDigit())
                                    .contentTransition(.numericText())
                            }
                        }
                    } footer: {
                        Text("Typical: 60–90 s for hypertrophy, 2–3 min for strength, 3–5 min for heavy compounds.")
                    }
                }
            }
            .navigationTitle("Rest Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Save

    private func save() {
        // Apply the override to the model. Setting it to nil reverts the
        // exercise to the global default.
        exercise.customRestDuration = useCustom ? seconds : nil

        // Walk every exercise and rebuild the rest-override map (collapsing
        // by case-insensitive name, most-recently-edited wins). Mirrors the
        // same logic in trackerApp.pushWatchContext so the watch sees one
        // consistent view.
        var map: [String: Int] = [:]
        var seenKeys = Set<String>()
        for ex in allExercises.reversed() where ex.customRestDuration != nil {
            let key = ex.name.lowercased()
            guard !seenKeys.contains(key) else { continue }
            seenKeys.insert(key)
            map[ex.name] = ex.customRestDuration
        }

        try? modelContext.save()
        PhoneConnectivityManager.shared.pushRestOverrides(map)
        onSave()
        dismiss()
    }
}
