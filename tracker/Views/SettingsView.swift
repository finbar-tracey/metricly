import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import StoreKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
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
    /// Strong/Hevy imports first surface a preview sheet so the user
    /// can confirm what's about to land before the rows go into
    /// SwiftData. Nil → no preview, no sheet. Set by the
    /// `.fileImporter` callback below; cleared on import-or-cancel.
    @State private var pendingImportPreview: ImportHelper.ImportPreview?
    // Cardio / PDF export
    @Query(sort: \CardioSession.date, order: .reverse) private var cardioSessions: [CardioSession]
    @State private var showingCardioExport = false
    @State private var cardioCSVURL: URL?
    @State private var showingPDFExport = false
    @State private var pdfURL: URL?
    @Environment(\.requestReview) private var requestReview

    private var settings: UserSettings {
        settingsArray.first ?? UserSettings()
    }

    var body: some View {
        Form {

            // MARK: - Profile (tap to edit)
            Section {
                NavigationLink(value: SettingsRoute.profile) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.18))
                                .frame(width: 48, height: 48)
                            Image(systemName: "person.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(settings.userName.isEmpty ? "Your Name" : settings.userName)
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundStyle(settings.userName.isEmpty ? .secondary : .primary)
                            Text(profileSubtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // MARK: - Preferences (workout behaviour)
            Section {
                HStack(spacing: 12) {
                    settingsIcon("timer", color: .orange)
                    Stepper(
                        "Default Rest: \(settings.defaultRestDuration)s",
                        value: Binding(
                            get: { settings.defaultRestDuration },
                            set: { settings.defaultRestDuration = $0 }
                        ),
                        in: 15...300,
                        step: 15
                    )
                }
                HStack(spacing: 12) {
                    settingsIcon("play.circle", color: .green)
                    Toggle("Auto-start Rest Timer", isOn: Binding(
                        get: { settings.autoStartRestTimer },
                        set: { settings.autoStartRestTimer = $0 }
                    ))
                }
                HStack(spacing: 12) {
                    settingsIcon("moon.circle.fill", color: .indigo)
                    Toggle("Focus Mode Reminder", isOn: Binding(
                        get: { settings.focusModeReminder },
                        set: { settings.focusModeReminder = $0 }
                    ))
                }
                HStack(spacing: 12) {
                    settingsIcon("target", color: .red)
                    Stepper(
                        "Weekly Goal: \(settings.weeklyGoal == 0 ? "Off" : "\(settings.weeklyGoal)x")",
                        value: Binding(
                            get: { settings.weeklyGoal },
                            set: { settings.weeklyGoal = $0 }
                        ),
                        in: 0...7
                    )
                }
            } header: {
                Text("Workout")
            } footer: {
                Text("Focus reminder prompts you to enable a Fitness Focus when starting a workout.")
            }

            // MARK: - Reminders + Templates (deep links — keep parent shell shallow)
            Section {
                NavigationLink(value: SettingsRoute.reminders) {
                    HStack(spacing: 12) {
                        settingsIcon("bell.fill", color: .red)
                        Text("Reminders")
                        Spacer()
                        Text(remindersSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                NavigationLink(value: SettingsRoute.templates) {
                    HStack(spacing: 12) {
                        settingsIcon("doc.on.doc.fill", color: .purple)
                        Text("Templates")
                        Spacer()
                        Text(templatesSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // MARK: - Nutrition (caffeine + water + creatine combined)
            Section {
                HStack(spacing: 12) {
                    settingsIcon("cup.and.saucer.fill", color: .brown)
                    Picker("Caffeine sensitivity", selection: Binding(
                        get: { settings.caffeineSensitivityEnum },
                        set: { settings.caffeineSensitivityEnum = $0 }
                    )) {
                        ForEach(CaffeineEntry.Sensitivity.allCases) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                }
                HStack(spacing: 12) {
                    settingsIcon("gauge.open.with.lines.needle.33percent.and.arrowtriangle", color: .orange)
                    Stepper(
                        "Daily caffeine: \(settings.dailyCaffeineLimit) mg",
                        value: Binding(
                            get: { settings.dailyCaffeineLimit },
                            set: { settings.dailyCaffeineLimit = $0 }
                        ),
                        in: 100...800, step: 50
                    )
                }
                HStack(spacing: 12) {
                    settingsIcon("drop.fill", color: .cyan)
                    Stepper(
                        "Daily water: \(settings.dailyWaterGoalMl) ml",
                        value: Binding(
                            get: { settings.dailyWaterGoalMl },
                            set: { settings.dailyWaterGoalMl = $0 }
                        ),
                        in: 1000...5000, step: 250
                    )
                }
                HStack(spacing: 12) {
                    settingsIcon("pill.fill", color: .blue)
                    Stepper(
                        "Creatine: \(String(format: "%.0f", settings.creatineDailyDose))g / day",
                        value: Binding(
                            get: { settings.creatineDailyDose },
                            set: { settings.creatineDailyDose = $0 }
                        ),
                        in: 1...25, step: 1
                    )
                }
                HStack(spacing: 12) {
                    settingsIcon("bolt.fill", color: .yellow)
                    Toggle("Creatine loading phase", isOn: Binding(
                        get: { settings.creatineLoadingPhase },
                        set: { settings.creatineLoadingPhase = $0 }
                    ))
                }
            } header: {
                Text("Nutrition")
            } footer: {
                Text("Loading phase uses 20g/day for 5–7 days, then switches to maintenance dose.")
            }

            // MARK: - Appearance
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Accent Color", systemImage: "paintpalette")
                        .font(.subheadline.weight(.medium))
                    HStack(spacing: 10) {
                        ForEach(AppAccentColor.allCases) { item in
                            let isSelected = settings.accentColor == item
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                                    settings.accentColor = item
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(item.color.gradient)
                                        .frame(width: 34, height: 34)
                                        .shadow(color: isSelected ? item.color.opacity(0.5) : .clear, radius: 6, x: 0, y: 2)
                                    if isSelected {
                                        Circle().strokeBorder(.white, lineWidth: 2.5).frame(width: 34, height: 34)
                                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                                    }
                                }
                                .scaleEffect(isSelected ? 1.18 : 1.0)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(item.rawValue)
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
                    }
                }
                .padding(.vertical, 6)

                HStack(spacing: 12) {
                    settingsIcon("moon.fill", color: .indigo)
                    Picker("Appearance", selection: Binding(
                        get: { settings.appearanceMode },
                        set: { settings.appearanceMode = $0 }
                    )) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                }
            } header: {
                Text("Appearance")
            }

            // MARK: ── APP ──────────────────────────────────

            Section {
                HStack(spacing: 12) {
                    settingsIcon("heart.fill", color: .red)
                    Toggle("Sync with Apple Health", isOn: Binding(
                        get: { settings.healthKitEnabled },
                        set: { newValue in
                            settings.healthKitEnabled = newValue
                            if newValue {
                                Task { try? await HealthKitManager.shared.requestAuthorization() }
                            }
                        }
                    ))
                }
                Button {
                    exportCSV()
                } label: {
                    HStack(spacing: 12) {
                        settingsIcon("square.and.arrow.up", color: .blue)
                        Text("Export Workouts as CSV")
                    }
                }
                .disabled(workouts.isEmpty)
                Button {
                    exportCardioCSV()
                } label: {
                    HStack(spacing: 12) {
                        settingsIcon("figure.run", color: .orange)
                        Text("Export Cardio as CSV")
                    }
                }
                .disabled(cardioSessions.isEmpty)
                Button {
                    exportPDF()
                } label: {
                    HStack(spacing: 12) {
                        settingsIcon("doc.richtext", color: .red)
                        Text("Export Workouts as PDF")
                    }
                }
                .disabled(workouts.isEmpty)
                Button {
                    showingImport = true
                } label: {
                    HStack(spacing: 12) {
                        settingsIcon("square.and.arrow.down", color: .green)
                        Text("Import Workouts from CSV")
                    }
                }
            } header: {
                Text("Health & Data")
            } footer: {
                Text("Completed workouts and body weight entries will be saved to Apple Health.")
            }

            // MARK: - iCloud Sync status
            Section {
                CloudSyncStatusRow(manager: SyncStatusManager.shared)
            } header: {
                Text("iCloud Sync")
            } footer: {
                Text("Your workout data syncs automatically across devices signed in to the same iCloud account.")
            }

            // MARK: - Strava
            StravaSettingsSection()

            Section {
                Button {
                    sendFeedbackEmail()
                } label: {
                    HStack(spacing: 12) {
                        settingsIcon("envelope.fill", color: .blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Send Feedback").font(.subheadline.weight(.semibold))
                            Text("Report bugs or suggest features").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Button {
                    requestReview()
                } label: {
                    HStack(spacing: 12) {
                        settingsIcon("star.fill", color: .yellow)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Rate on App Store").font(.subheadline.weight(.semibold))
                            Text("Help us with a quick review").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Link(destination: URL(string: "https://apps.apple.com/ie/app/metricly/id6760858258")!) {
                    HStack(spacing: 12) {
                        settingsIcon("arrow.up.forward.app.fill", color: .accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("View on App Store").font(.subheadline.weight(.semibold))
                            Text("Share with friends").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Link(destination: URL(string: "https://gist.githubusercontent.com/finbar-tracey/926003a49594537367eeb27d077267de/raw")!) {
                    HStack(spacing: 12) {
                        settingsIcon("hand.raised.fill", color: .indigo)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Privacy Policy").font(.subheadline.weight(.semibold))
                            Text("How we handle your data").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("About")
            } footer: {
                Text("We read every piece of feedback. Thank you for helping improve Metricly!")
            }
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
                    // Two-phase: plan() detects the format and parses
                    // Strong/Hevy into a preview structure; Metricly's
                    // own format is fast + self-explanatory so it
                    // commits straight away.
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
                    importResult = "Successfully imported \(count) workout\(count == 1 ? "" : "s")."
                    showImportResult = true
                },
                onCancel: {
                    pendingImportPreview = nil
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

    // MARK: - Route + summary helpers

    /// One-line summaries for the three NavigationLink rows in the parent
    /// Settings shell.
    private var profileSubtitle: String {
        var parts: [String] = []
        parts.append(settings.useKilograms ? "Kilograms" : "Pounds")
        if settings.biologicalSex == "male"   { parts.append("Male") }
        if settings.biologicalSex == "female" { parts.append("Female") }
        return parts.joined(separator: " · ")
    }

    private var remindersSummary: String {
        if settings.reminderDays.isEmpty { return "Off" }
        let count = settings.reminderDays.count
        return "\(count) day\(count == 1 ? "" : "s")"
    }

    private var templatesSummary: String {
        templates.isEmpty ? "None saved" : "\(templates.count) saved"
    }

    private func settingsIcon(_ name: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [color, color.opacity(0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 30, height: 30)
                .shadow(color: color.opacity(0.40), radius: 4, y: 2)
            Image(systemName: name)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
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

    private func sendFeedbackEmail() {
        let subject = "Metricly Feedback"
        let urlString = "mailto:finbartracey@gmail.com?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject)"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
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

/// Routes for the parent Settings screen's NavigationLinks. Each maps to a
/// dedicated sub-view (Profile / Reminders / Templates) so the parent shell
/// stays scannable.
enum SettingsRoute: Hashable {
    case profile
    case reminders
    case templates
}
