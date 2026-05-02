import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UserNotifications
import StoreKit

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
    @State private var templateToDelete: Workout?
    @State private var notificationStatus: UNAuthorizationStatus?
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

            // MARK: - Profile Header
            Section {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 56, height: 56)
                        Image(systemName: "person.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(settings.userName.isEmpty ? "Your Name" : settings.userName)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(settings.userName.isEmpty ? .secondary : .primary)
                        Text(settings.useKilograms ? "Kilograms · " : "Pounds · ")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        + Text(settings.biologicalSex == "male" ? "Male" : settings.biologicalSex == "female" ? "Female" : "Sex not set")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }

            // MARK: ── WORKOUT ─────────────────────────────

            Section {
                HStack(spacing: 12) {
                    settingsIcon("scalemass", color: .blue)
                    Toggle("Use Kilograms", isOn: Binding(
                        get: { settings.useKilograms },
                        set: { settings.useKilograms = $0 }
                    ))
                }
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
            } header: {
                Text("Workout")
            } footer: {
                Text("When Focus reminder is on, you'll be prompted to enable your Fitness Focus when starting a workout.")
            }

            Section {
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
                                if !settings.reminderDays.contains(day) { settings.reminderDays.append(day) }
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
                            hour: settings.reminderHour, minute: settings.reminderMinute
                        )) ?? .now
                    },
                    set: { date in
                        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                        settings.reminderHour = components.hour ?? 9
                        settings.reminderMinute = components.minute ?? 0
                        updateReminders()
                    }
                ), displayedComponents: .hourAndMinute)
                if notificationStatus == .denied {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Notifications Disabled").font(.subheadline.weight(.semibold))
                            Text("Enable in Settings to receive reminders.").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.caption.bold())
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Reminders")
            } footer: {
                Text("Get notified on your training days.")
            }

            Section {
                NavigationLink(value: "templateMarketplace") {
                    HStack(spacing: 12) {
                        settingsIcon("square.grid.2x2", color: .purple)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Browse Program Templates").font(.subheadline.weight(.semibold))
                            Text("PPL, 5/3/1, Starting Strength & more").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                if templates.isEmpty {
                    HStack(spacing: 12) {
                        settingsIcon("doc.on.doc", color: .secondary)
                        Text("No templates saved yet.").foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(templates) { template in
                        NavigationLink(value: template) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.accentColor.opacity(0.12))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color.accentColor)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(template.name).font(.subheadline.weight(.semibold))
                                    Text("\(template.exercises.count) exercises").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete { offsets in
                        if let index = offsets.first { templateToDelete = templates[index] }
                    }
                }
            } header: {
                Text("Templates")
            }

            // MARK: ── NUTRITION ────────────────────────────

            Section {
                HStack(spacing: 12) {
                    settingsIcon("cup.and.saucer.fill", color: .brown)
                    Picker("Sensitivity", selection: Binding(
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
                        "Daily Limit: \(settings.dailyCaffeineLimit) mg",
                        value: Binding(
                            get: { settings.dailyCaffeineLimit },
                            set: { settings.dailyCaffeineLimit = $0 }
                        ),
                        in: 100...800, step: 50
                    )
                }
            } header: {
                Text("Caffeine")
            } footer: {
                Text("The FDA recommends ≤400 mg/day for most adults.")
            }

            Section {
                HStack(spacing: 12) {
                    settingsIcon("drop.fill", color: .cyan)
                    Stepper(
                        "Daily Goal: \(settings.dailyWaterGoalMl) ml",
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
                    Toggle("Creatine Loading Phase", isOn: Binding(
                        get: { settings.creatineLoadingPhase },
                        set: { settings.creatineLoadingPhase = $0 }
                    ))
                }
            } header: {
                Text("Water & Creatine")
            } footer: {
                Text("Loading phase uses 20g/day for 5–7 days, then switches to maintenance dose.")
            }

            // MARK: ── PROFILE & APPEARANCE ────────────────

            Section {
                HStack(spacing: 12) {
                    settingsIcon("person.text.rectangle", color: .cyan)
                    TextField("Your Name", text: Binding(
                        get: { settings.userName },
                        set: { settings.userName = $0 }
                    ))
                }
                HStack(spacing: 12) {
                    settingsIcon("person.fill", color: .cyan)
                    Picker("Sex", selection: Binding(
                        get: { settings.biologicalSex },
                        set: { settings.biologicalSex = $0 }
                    )) {
                        Text("Not Set").tag("")
                        Text("Male").tag("male")
                        Text("Female").tag("female")
                    }
                }
                HStack(spacing: 12) {
                    settingsIcon("ruler", color: .mint)
                    let isMetric = settings.useKilograms
                    Stepper(
                        "Height: \(formatHeight(settings.heightCm, metric: isMetric))",
                        value: Binding(
                            get: { settings.heightCm },
                            set: { settings.heightCm = $0 }
                        ),
                        in: 100...250,
                        step: isMetric ? 1 : 2.54
                    )
                }
            } header: {
                Text("Profile")
            } footer: {
                Text("Height and sex are used for body fat % estimation.")
            }

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
        .task {
            notificationStatus = await ReminderManager.checkAuthorizationStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { notificationStatus = await ReminderManager.checkAuthorizationStatus() }
        }
        .navigationTitle("Settings")
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
        .alert("Delete Template?", isPresented: Binding(
            get: { templateToDelete != nil },
            set: { if !$0 { templateToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let template = templateToDelete {
                    modelContext.delete(template)
                    templateToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { templateToDelete = nil }
        } message: {
            if let template = templateToDelete {
                Text("Are you sure you want to delete \"\(template.name)\"?")
            }
        }
    }

    private func settingsIcon(_ name: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(color.gradient)
                .frame(width: 28, height: 28)
            Image(systemName: name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private func formatHeight(_ cm: Double, metric: Bool) -> String {
        if cm <= 0 { return "Not Set" }
        if metric {
            return "\(Int(cm)) cm"
        } else {
            let totalInches = cm / 2.54
            let feet = Int(totalInches) / 12
            let inches = Int(totalInches) % 12
            return "\(feet)'\(inches)\""
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
