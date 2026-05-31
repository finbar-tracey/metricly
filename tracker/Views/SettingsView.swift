import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appServices) private var appServices
    @Environment(\.scenePhase) private var scenePhase
    @Query private var settingsArray: [UserSettings]
    @Query(filter: #Predicate<Workout> { $0.isTemplate }, sort: \Workout.name)
    private var templates: [Workout]
    @Query(filter: #Predicate<Workout> { !$0.isTemplate }, sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]
    @Query(sort: \CardioSession.date, order: .reverse) private var cardioSessions: [CardioSession]

    @State private var showingExport = false
    @State private var csvURL: URL?
    @State private var showExportError = false
    @State private var showingImport = false
    @State private var importResult: String?
    @State private var showImportResult = false
    @State private var showImportError = false
    @State private var importErrorMessage = ""
    @State private var pendingImportPreview: ImportHelper.ImportPreview?
    @State private var pendingImportSuccess: ImportSuccessPresentation?
    @State private var showingCardioExport = false
    @State private var cardioCSVURL: URL?
    @State private var showingPDFExport = false
    @State private var pdfURL: URL?
    @AppStorage("celebrationsEnabled") private var celebrationsEnabled = true

    private var settings: UserSettings {
        settingsArray.first ?? UserSettings()
    }

    var body: some View {
        Form {
            SettingsProfileSection(settings: settings)
            SettingsPreferencesSection(settings: settings, celebrationsEnabled: $celebrationsEnabled)
            SettingsHeartRateZonesSection(settings: settings)
            SettingsRemindersTemplatesSection(settings: settings, templates: templates)
            SettingsNutritionSection(settings: settings)
            SettingsAppearanceSection(settings: settings)
            SettingsAppSection(
                settings: settings,
                workoutsEmpty: workouts.isEmpty,
                cardioSessionsEmpty: cardioSessions.isEmpty,
                onExportWorkouts: exportCSV,
                onExportCardio: exportCardioCSV,
                onExportPDF: exportPDF,
                onImport: { showingImport = true }
            )
            SettingsICloudSyncSection()
            StravaSettingsSection()
            SettingsAboutSection()
        }
        .navigationTitle("Settings")
        .navigationDestination(for: SettingsRoute.self) { route in
            switch route {
            case .profile:   ProfileSettingsView()
            case .reminders: RemindersSettingsView()
            case .templates: TemplatesSettingsView()
            }
        }
        .navigationDestination(for: Workout.self) { template in
            TemplateEditView(template: template)
        }
        .navigationDestination(for: String.self) { value in
            if value == "templateMarketplace" {
                TemplateMarketplaceView()
            }
        }
        .sheet(isPresented: $showingExport) {
            if let url = csvURL {
                ShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $showingCardioExport) {
            if let url = cardioCSVURL {
                ShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $showingPDFExport) {
            if let url = pdfURL {
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
                    switch try ImportHelper.plan(from: url) {
                    case .preview(let preview):
                        pendingImportPreview = preview
                    case .metriclyDirect:
                        let count = try ImportHelper.importCSV(from: url, into: modelContext)
                        importResult = "Successfully imported \(count) workout\(count == 1 ? "" : "s")."
                        showImportResult = true
                    }
                } catch {
                    importErrorMessage = error.localizedDescription
                    showImportError = true
                }
            case .failure(let error):
                importErrorMessage = error.localizedDescription
                showImportError = true
            }
        }
        .sheet(item: $pendingImportPreview) { preview in
            ImportPreviewSheet(
                preview: preview,
                onImport: {
                    let count = ImportHelper.commitPreview(preview, into: modelContext)
                    pendingImportPreview = nil
                    if count > 0 {
                        let analysis = ImportAnalyzer.analyze(preview.workouts)
                        pendingImportSuccess = ImportSuccessPresentation(analysis: analysis)
                    } else {
                        importResult = "Nothing was imported."
                        showImportResult = true
                    }
                },
                onCancel: {
                    pendingImportPreview = nil
                }
            )
        }
        .sheet(item: $pendingImportSuccess) { presentation in
            ImportSuccessSheet(
                analysis: presentation.analysis,
                onStartRecommended: {
                    pendingImportSuccess = nil
                    appServices.router.openTrainingTab()
                },
                onDismiss: {
                    pendingImportSuccess = nil
                }
            )
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

    private func exportCardioCSV() {
        let csv = ExportHelper.generateCardioCSV(sessions: Array(cardioSessions))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("cardio.csv")
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            cardioCSVURL = url
            showingCardioExport = true
        } catch {
            showExportError = true
        }
    }

    private func exportPDF() {
        let data = ExportHelper.generateWorkoutPDF(workouts: workouts)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("metricly_workouts.pdf")
        do {
            try data.write(to: url)
            pdfURL = url
            showingPDFExport = true
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
}

enum SettingsRoute: Hashable {
    case profile
    case reminders
    case templates
}

private struct ImportSuccessPresentation: Identifiable {
    let id = UUID()
    let analysis: ImportAnalysis
}
