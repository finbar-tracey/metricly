import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsArray: [UserSettings]
    @Query(filter: #Predicate<Workout> { $0.isTemplate }, sort: \Workout.name)
    private var templates: [Workout]
    @Query(filter: #Predicate<Workout> { !$0.isTemplate }, sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]
    @State private var showingExport = false
    @State private var csvURL: URL?
    @State private var showExportError = false

    private var settings: UserSettings {
        if let existing = settingsArray.first {
            return existing
        }
        let new = UserSettings()
        modelContext.insert(new)
        return new
    }

    var body: some View {
        Form {
            Section {
                Toggle("Use Kilograms", isOn: Binding(
                    get: { settings.useKilograms },
                    set: { settings.useKilograms = $0 }
                ))
                Stepper(
                    "Default Rest: \(settings.defaultRestDuration)s",
                    value: Binding(
                        get: { settings.defaultRestDuration },
                        set: { settings.defaultRestDuration = $0 }
                    ),
                    in: 15...300,
                    step: 15
                )
                Toggle("Auto-start Rest Timer", isOn: Binding(
                    get: { settings.autoStartRestTimer },
                    set: { settings.autoStartRestTimer = $0 }
                ))
            } header: {
                Text("General")
            } footer: {
                Text("When off, a \"Start Rest\" button appears after each set instead of starting automatically.")
            }

            Section {
                if templates.isEmpty {
                    Text("No templates saved yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(templates) { template in
                        VStack(alignment: .leading) {
                            Text(template.name)
                                .font(.headline)
                            Text(template.exercises.map(\.name).joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete(perform: deleteTemplates)
                }
            } header: {
                Text("Templates")
            }
            Section {
                Button {
                    exportCSV()
                } label: {
                    Label("Export Workouts as CSV", systemImage: "square.and.arrow.up")
                }
                .disabled(workouts.isEmpty)
            } header: {
                Text("Data")
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showingExport) {
            if let url = csvURL {
                ShareSheet(items: [url])
            }
        }
        .alert("Export Failed", isPresented: $showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Could not create the CSV file. Please try again.")
        }
    }

    private func exportCSV() {
        let csv = ExportHelper.generateCSV(workouts: workouts)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("workouts.csv")
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            csvURL = url
            showingExport = true
        } catch {
            showExportError = true
        }
    }

    private func deleteTemplates(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(templates[index])
        }
    }
}
