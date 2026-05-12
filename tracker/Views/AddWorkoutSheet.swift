import SwiftUI
import SwiftData

struct AddWorkoutSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Workout> { $0.isTemplate }, sort: \Workout.name)
    private var templates: [Workout]
    @Query private var settingsArray: [UserSettings]

    @State private var name: String = ""
    @State private var date = Date.now
    @State private var selectedTemplate: Workout?
    /// Backdate is rare — keep the date picker behind a disclosure.
    @State private var showDateOverride = false

    /// Today's planned workout name. Prefers the adaptive recommendation
    /// from `TodayPlanEngine` (cached in `TodayPlanStore`) — which can
    /// substitute the static schedule with something the engine thinks
    /// fits today's recovery better — and falls back to the static
    /// `UserSettings.weeklyPlan` entry when no plan is cached. Rest-day
    /// recommendations fall back to the scheduled name so the user can
    /// still override-and-train if they want to.
    private var todayPlanName: String {
        if let plan = TodayPlanStore.load() {
            if plan.intensity != .rest, !plan.recommendedName.isEmpty, plan.recommendedName != "—" {
                return plan.recommendedName
            }
            if let scheduled = plan.scheduledName, !scheduled.isEmpty {
                return scheduled
            }
        }
        let weekday = Calendar.current.component(.weekday, from: .now)
        return settingsArray.first?.weeklyPlan[weekday] ?? ""
    }

    /// Short "why" line for today's recommendation — surfaced under the
    /// banner so the user sees what's driving the adaptive choice.
    /// Returns `nil` when no plan is available or there's nothing useful
    /// to say.
    private var todayPlanHint: String? {
        guard let plan = TodayPlanStore.load() else { return nil }
        switch plan.intensity {
        case .rest:     return "Recovery is low — rest is recommended"
        case .light:    return "Go light today — partial recovery"
        case .hard:     return "Well-recovered — good day to push"
        case .moderate: return plan.reasons.first
        }
    }

    /// Template that matches today's plan name (case-insensitive).
    private var planTemplate: Workout? {
        guard !todayPlanName.isEmpty else { return nil }
        return templates.first { $0.name.localizedCaseInsensitiveCompare(todayPlanName) == .orderedSame }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Today's plan banner — only shows when something is scheduled
                // and the user hasn't manually overridden the choice yet.
                if !todayPlanName.isEmpty,
                   selectedTemplate?.name.localizedCaseInsensitiveCompare(todayPlanName) != .orderedSame,
                   name.localizedCaseInsensitiveCompare(todayPlanName) != .orderedSame {
                    todaysPlanBanner
                }

                detailsSection

                if !templates.isEmpty {
                    templatesSection
                }

                if let template = selectedTemplate, !template.exercises.isEmpty {
                    exercisesPreviewSection(template)
                }
            }
            .navigationTitle("New Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        createWorkout()
                        modelContext.saveOrLog()
                        HapticsManager.workoutStarted()
                        dismiss()
                    }
                    .font(.headline)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: applyDefaults)
        }
    }

    // MARK: - Sections

    /// Single-tap banner offering to use today's planned workout. Pre-applies
    /// the matching template if one exists.
    private var todaysPlanBanner: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.3)) {
                name = todayPlanName
                if let plan = planTemplate {
                    selectedTemplate = plan
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today's plan")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                    Text(planTemplate != nil
                         ? "\(todayPlanName) - template ready"
                         : todayPlanName)
                        .font(.subheadline.weight(.semibold))
                    if let hint = todayPlanHint {
                        Text(hint)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text("Use")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.accentColor, in: Capsule())
            }
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.accentColor.opacity(0.06))
    }

    private var detailsSection: some View {
        Section {
            TextField("Workout Name", text: $name)
                .textInputAutocapitalization(.words)

            // Date is hidden behind a disclosure — almost everyone is starting
            // "now" and doesn't need to see the picker.
            if showDateOverride {
                DatePicker("Date", selection: $date, displayedComponents: .date)
            } else {
                Button {
                    withAnimation { showDateOverride = true }
                } label: {
                    HStack {
                        Text("Different date")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private var templatesSection: some View {
        Section("Template") {
            // "Start blank" option as the first row — easy to start without
            // a template, no need to scroll past everything.
            Button {
                withAnimation(.spring(response: 0.25)) {
                    selectedTemplate = nil
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                    Text("Start blank")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Spacer()
                    if selectedTemplate == nil {
                        Image(systemName: "checkmark")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .buttonStyle(.plain)

            ForEach(templates) { template in
                templateRow(template)
            }
        }
    }

    private func templateRow(_ template: Workout) -> some View {
        let isSelected = selectedTemplate?.persistentModelID == template.persistentModelID
        let isToday = !todayPlanName.isEmpty
            && template.name.localizedCaseInsensitiveCompare(todayPlanName) == .orderedSame
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.25)) {
                selectedTemplate = template
                name = template.name
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(template.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        if isToday {
                            Text("TODAY")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Color.accentColor, in: Capsule())
                        }
                    }
                    Text("\(template.exercises.count) exercise\(template.exercises.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(template.name), \(template.exercises.count) exercises\(isToday ? ", today's plan" : "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func exercisesPreviewSection(_ template: Workout) -> some View {
        Section("Exercises") {
            ForEach(template.exercises.sorted { $0.order < $1.order }) { exercise in
                HStack(spacing: 10) {
                    if let category = exercise.category {
                        MuscleIconView(group: category, color: Color.accentColor)
                            .frame(width: 14, height: 14)
                    } else {
                        Image(systemName: "dumbbell")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(exercise.name)
                        .font(.subheadline)
                    Spacer()
                    if let category = exercise.category {
                        Text(category.rawValue)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    // MARK: - Setup

    /// First-appear defaults: pre-fill name + select matching template.
    /// Avoids re-running on every appearance (e.g. if the sheet is dismissed
    /// and re-opened) since `name` won't be empty after the first run.
    private func applyDefaults() {
        guard name.isEmpty else { return }
        if !todayPlanName.isEmpty {
            name = todayPlanName
            if let plan = planTemplate {
                selectedTemplate = plan
            }
        } else {
            name = Self.defaultWorkoutName()
        }
    }

    private func createWorkout() {
        let workout = Workout(name: name, date: date)
        modelContext.insert(workout)
        if let template = selectedTemplate {
            workout.copyExercises(from: template.exercises, into: modelContext)
        }
        // Publish to the Watch so its complications + start screen show
        // "In Progress · <name>" while this session is live on the phone.
        PhoneConnectivityManager.shared.publishActiveWorkout(
            name: workout.name,
            startedAt: workout.date
        )
    }

    private static func defaultWorkoutName() -> String {
        "Workout - \(Date.now.formatted(.dateTime.month(.abbreviated).day()))"
    }
}
