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
    @Environment(\.requestReview) private var requestReview

    private var settings: UserSettings {
        settingsArray.first ?? UserSettings()
    }

    var body: some View {
        Form {
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
                Text("General")
            } footer: {
                Text("When Focus reminder is on, you'll be prompted to enable your Fitness Focus when starting a workout, and reminded to disable it when finishing.")
            }

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
                Text("Used for body fat % estimation. Height and sex are required for the Navy method calculator.")
            }

            Section {
                let accentColors: [(name: String, color: Color)] = [
                    ("blue", .blue), ("indigo", .indigo), ("purple", .purple),
                    ("pink", .pink), ("red", .red), ("orange", .orange),
                    ("green", .green), ("teal", .teal)
                ]
                VStack(alignment: .leading, spacing: 10) {
                    Label("Accent Color", systemImage: "paintpalette")
                        .font(.subheadline)
                    HStack(spacing: 12) {
                        ForEach(accentColors, id: \.name) { item in
                            Button {
                                settings.accentColorName = item.name
                            } label: {
                                Circle()
                                    .fill(item.color.gradient)
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        if settings.accentColorName == item.name {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .scaleEffect(settings.accentColorName == item.name ? 1.15 : 1.0)
                                    .animation(.spring(response: 0.3), value: settings.accentColorName)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(item.name)
                            .accessibilityAddTraits(settings.accentColorName == item.name ? .isSelected : [])
                        }
                    }
                }
                .padding(.vertical, 4)

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
                if notificationStatus == .denied {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Notifications Disabled")
                                .font(.subheadline.weight(.semibold))
                            Text("Enable in Settings to receive reminders.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
                Text("Workout Reminders")
            } footer: {
                Text("Get notified on your training days. Select the days you plan to work out.")
            }

            Section {
                NavigationLink(value: "templateMarketplace") {
                    HStack(spacing: 12) {
                        settingsIcon("square.grid.2x2", color: .purple)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Browse Program Templates")
                                .font(.subheadline.weight(.semibold))
                            Text("PPL, 5/3/1, Starting Strength & more")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if templates.isEmpty {
                    HStack(spacing: 12) {
                        settingsIcon("doc.on.doc", color: .secondary)
                        Text("No templates saved yet.")
                            .foregroundStyle(.secondary)
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
                                    Text(template.name)
                                        .font(.subheadline.weight(.semibold))
                                    Text("\(template.exercises.count) exercises")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete { offsets in
                        if let index = offsets.first {
                            templateToDelete = templates[index]
                        }
                    }
                }
            } header: {
                Text("Templates")
            }
            Section {
                HStack(spacing: 12) {
                    settingsIcon("heart.fill", color: .red)
                    Toggle("Sync with Apple Health", isOn: Binding(
                        get: { settings.healthKitEnabled },
                        set: { newValue in
                            settings.healthKitEnabled = newValue
                            if newValue {
                                Task {
                                    try? await HealthKitManager.shared.requestAuthorization()
                                }
                            }
                        }
                    ))
                }
            } header: {
                Text("Health")
            } footer: {
                Text("Completed workouts and body weight entries will be saved to Apple Health.")
            }

            Section {
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
                    showingImport = true
                } label: {
                    HStack(spacing: 12) {
                        settingsIcon("square.and.arrow.down", color: .green)
                        Text("Import Workouts from CSV")
                    }
                }
            } header: {
                Text("Data")
            }

            Section {
                Button {
                    sendFeedbackEmail()
                } label: {
                    HStack(spacing: 12) {
                        settingsIcon("envelope.fill", color: .blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Send Feedback")
                                .font(.subheadline.weight(.semibold))
                            Text("Report bugs or suggest features")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Button {
                    requestReview()
                } label: {
                    HStack(spacing: 12) {
                        settingsIcon("star.fill", color: .yellow)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Rate on App Store")
                                .font(.subheadline.weight(.semibold))
                            Text("Help us with a quick review")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                // TODO: Replace with your actual GitHub issues URL
                Link(destination: URL(string: "https://github.com/metricly/issues")!) {
                    HStack(spacing: 12) {
                        settingsIcon("ladybug.fill", color: .green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Report an Issue")
                                .font(.subheadline.weight(.semibold))
                            Text("Open a GitHub issue")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Feedback")
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

    private func sendFeedbackEmail() {
        // TODO: Replace with your actual feedback email
        let subject = "Metricly Feedback"
        let urlString = "mailto:feedback@metricly.app?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject)"
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
