import SwiftUI
import SwiftData

struct WorkoutScheduleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsArray: [UserSettings]
    @Query(filter: #Predicate<Workout> { $0.isTemplate }, sort: \Workout.name) private var templates: [Workout]

    @State private var editingDay: Int? = nil
    @State private var draftName: String = ""

    private var settings: UserSettings? { settingsArray.first }
    private var plan: [Int: String] { settings?.weeklyPlan ?? [:] }

    private let displayOrder: [(weekday: Int, label: String, short: String)] = [
        (2, "Monday",    "Mon"),
        (3, "Tuesday",   "Tue"),
        (4, "Wednesday", "Wed"),
        (5, "Thursday",  "Thu"),
        (6, "Friday",    "Fri"),
        (7, "Saturday",  "Sat"),
        (1, "Sunday",    "Sun"),
    ]

    private var todayWeekday: Int {
        Calendar.current.component(.weekday, from: .now)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                weekCard
                if !templates.isEmpty { templatesCard }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Weekly Schedule")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: Binding(
            get: { editingDay != nil },
            set: { if !$0 { editingDay = nil } }
        )) {
            if let day = editingDay {
                let dayLabel = displayOrder.first { $0.weekday == day }?.label ?? ""
                DayEditorSheet(
                    dayLabel: dayLabel,
                    draftName: $draftName,
                    onSave: { savePlan(for: day) },
                    onCancel: { editingDay = nil },
                    onClear: { draftName = "" }
                )
            }
        }
    }

    // MARK: - Week Card

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "This Week", icon: "calendar", color: .accentColor)

            VStack(spacing: 0) {
                ForEach(displayOrder, id: \.weekday) { day in
                    let isToday = day.weekday == todayWeekday
                    let name = plan[day.weekday]

                    Button {
                        draftName = name ?? ""
                        editingDay = day.weekday
                    } label: {
                        HStack(spacing: 14) {
                            Text(day.short)
                                .font(.system(size: 12, weight: .bold))
                                .frame(width: 38, height: 38)
                                .background(
                                    isToday ? Color.accentColor : Color(.tertiarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 10)
                                )
                                .foregroundStyle(isToday ? .white : .secondary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(day.label)
                                    .font(.subheadline.weight(isToday ? .semibold : .regular))
                                    .foregroundStyle(isToday ? .primary : .secondary)
                                if let n = name, !n.isEmpty {
                                    Text(n)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                } else {
                                    Text("Rest day")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }

                            Spacer()

                            if let n = name, !n.isEmpty {
                                Image(systemName: "dumbbell.fill")
                                    .font(.caption)
                                    .foregroundStyle(Color.accentColor)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)

                    if day.weekday != 1 {
                        Divider().padding(.leading, 68)
                    }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    // MARK: - Templates Card

    private var templatesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Your Templates", icon: "doc.on.doc.fill", color: .purple)
            Text("Tap a template to quickly assign it to a day.")
                .font(.caption)
                .foregroundStyle(.secondary)

            FlowLayout(spacing: 8) {
                ForEach(templates) { template in
                    Button {
                        draftName = template.name
                        editingDay = todayWeekday
                    } label: {
                        Text(template.name)
                            .font(.caption.bold())
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Color.accentColor.opacity(0.1), in: Capsule())
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .appCard()
    }

    // MARK: - Save

    private func savePlan(for day: Int) {
        var current = settings?.weeklyPlan ?? [:]
        let trimmed = draftName.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            current.removeValue(forKey: day)
        } else {
            current[day] = trimmed
        }
        settings?.weeklyPlan = current
        modelContext.saveOrLog()
        editingDay = nil
    }
}

// MARK: - Day Editor Sheet (own struct avoids ForEach ambiguity inside Form)

private struct DayEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Workout> { $0.isTemplate }, sort: \Workout.name)
    private var templates: [Workout]

    let dayLabel: String
    @Binding var draftName: String
    let onSave: () -> Void
    let onCancel: () -> Void
    let onClear: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Workout name (leave empty for rest)", text: $draftName)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text(dayLabel)
                } footer: {
                    Text("Leave blank to mark this as a rest day.")
                }

                if !templates.isEmpty {
                    Section("Quick pick from templates") {
                        ForEach(templates) { template in
                            templateRow(template)
                        }
                    }
                }

                Section {
                    Button(role: .destructive, action: onClear) {
                        Label("Clear (rest day)", systemImage: "xmark.circle")
                    }
                }
            }
            .navigationTitle("Set Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                        .font(.headline)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // Extracted into a function so ForEach content is a simple ViewBuilder call
    private func templateRow(_ template: Workout) -> some View {
        Button {
            draftName = template.name
        } label: {
            HStack {
                Text(template.name)
                    .foregroundStyle(.primary)
                Spacer()
                if draftName == template.name {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }
}
