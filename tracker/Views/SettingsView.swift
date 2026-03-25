import SwiftUI
import SwiftData
import UniformTypeIdentifiers

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
    @State private var showingImport = false
    @State private var importResult: String?
    @State private var showImportResult = false
    @State private var showImportError = false
    @State private var importErrorMessage = ""

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
                Stepper(
                    "Weekly Goal: \(settings.weeklyGoal == 0 ? "Off" : "\(settings.weeklyGoal)x")",
                    value: Binding(
                        get: { settings.weeklyGoal },
                        set: { settings.weeklyGoal = $0 }
                    ),
                    in: 0...7
                )
            } header: {
                Text("Goals")
            } footer: {
                Text("Set a weekly workout target. A progress ring will appear on the home screen. Set to Off to hide it.")
            }

            Section {
                let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                ForEach(1...7, id: \.self) { day in
                    Toggle(dayNames[day - 1], isOn: Binding(
                        get: { settings.reminderDays.contains(day) },
                        set: { enabled in
                            if enabled {
                                if !settings.reminderDays.contains(day) {
                                    settings.reminderDays.append(day)
                                }
                            } else {
                                settings.reminderDays.removeAll { $0 == day }
                            }
                            updateReminders()
                        }
                    ))
                }
                DatePicker("Reminder Time", selection: Binding(
                    get: {
                        Calendar.current.date(from: DateComponents(
                            hour: settings.reminderHour,
                            minute: settings.reminderMinute
                        )) ?? .now
                    },
                    set: { date in
                        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                        settings.reminderHour = components.hour ?? 9
                        settings.reminderMinute = components.minute ?? 0
                        updateReminders()
                    }
                ), displayedComponents: .hourAndMinute)
            } header: {
                Text("Workout Reminders")
            } footer: {
                Text("Get notified on your training days. Select the days you plan to work out.")
            }

            Section {
                if templates.isEmpty {
                    Text("No templates saved yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(templates) { template in
                        NavigationLink(value: template) {
                            VStack(alignment: .leading) {
                                Text(template.name)
                                    .font(.headline)
                                Text(template.exercises.sorted { $0.order < $1.order }.map(\.name).joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
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
                Button {
                    showingImport = true
                } label: {
                    Label("Import Workouts from CSV", systemImage: "square.and.arrow.down")
                }
            } header: {
                Text("Data")
            }
        }
        .navigationTitle("Settings")
        .navigationDestination(for: Workout.self) { template in
            TemplateEditView(template: template)
        }
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
        .fileImporter(
            isPresented: $showingImport,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                do {
                    let count = try ImportHelper.importCSV(from: url, into: modelContext)
                    importResult = "Successfully imported \(count) workout\(count == 1 ? "" : "s")."
                    showImportResult = true
                } catch {
                    importErrorMessage = error.localizedDescription
                    showImportError = true
                }
            case .failure(let error):
                importErrorMessage = error.localizedDescription
                showImportError = true
            }
        }
        .alert("Import Successful", isPresented: $showImportResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importResult ?? "")
        }
        .alert("Import Failed", isPresented: $showImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage)
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

    private func updateReminders() {
        if settings.reminderDays.isEmpty {
            ReminderManager.removeAllReminders()
        } else {
            ReminderManager.scheduleReminders(
                days: settings.reminderDays,
                hour: settings.reminderHour,
                minute: settings.reminderMinute
            )
        }
    }

    private func deleteTemplates(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(templates[index])
        }
    }
}
