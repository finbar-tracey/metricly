import SwiftUI
import SwiftData

/// Edits the bits of `UserSettings` that describe the person, not the app's
/// behaviour: name, units, biological sex, height. Reached from the Profile
/// row in `SettingsView` via `SettingsRoute.profile`.
struct ProfileSettingsView: View {
    @Query private var settingsArray: [UserSettings]
    @Environment(\.modelContext) private var modelContext

    private var settings: UserSettings {
        if let existing = settingsArray.first { return existing }
        let new = UserSettings()
        modelContext.insert(new)
        return new
    }

    var body: some View {
        Form {
            Section {
                TextField("Your name", text: Binding(
                    get: { settings.userName },
                    set: { settings.userName = $0 }
                ))
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
            } header: {
                Text("Name")
            }

            Section {
                Picker("Weight unit", selection: Binding(
                    get: { settings.useKilograms },
                    set: { settings.useKilograms = $0 }
                )) {
                    Text("Kilograms").tag(true)
                    Text("Pounds").tag(false)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Units")
            }

            Section {
                Picker("Biological sex", selection: Binding(
                    get: { settings.biologicalSex },
                    set: { settings.biologicalSex = $0 }
                )) {
                    Text("Not set").tag("")
                    Text("Male").tag("male")
                    Text("Female").tag("female")
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Biological sex")
            } footer: {
                Text("Used for body-fat estimates and recovery calculations.")
            }

            Section {
                Stepper(
                    heightLabel,
                    value: Binding(
                        get: { settings.heightCm },
                        set: { settings.heightCm = $0 }
                    ),
                    in: 0...250,
                    step: 1
                )
            } header: {
                Text("Height")
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heightLabel: String {
        if settings.heightCm <= 0 { return "Height: Not set" }
        if settings.useKilograms {
            return "Height: \(Int(settings.heightCm)) cm"
        }
        let inches = settings.heightCm / 2.54
        let feet = Int(inches) / 12
        let remainder = Int(inches.rounded()) % 12
        return "Height: \(feet)′\(remainder)″"
    }
}
