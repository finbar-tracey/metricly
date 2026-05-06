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
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        draftName = name ?? ""
                        editingDay = day.weekday
                    } label: {
                        HStack(spacing: 14) {
                            Text(day.short)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .frame(width: 42, height: 42)
                                .background {
                                    if isToday {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color.accentColor, Color.accentColor.opacity(0.72)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .shadow(color: Color.accentColor.opacity(0.40), radius: 6, y: 3)
                                    } else {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color(.tertiarySystemGroupedBackground))
                                    }
                                }
                                .foregroundStyle(isToday ? .white : .secondary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(day.label)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(isToday ? .primary : .secondary)
                                if let n = name, !n.isEmpty {
                                    Text(n)
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
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
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                    }
                    .buttonStyle(.pressableCard)

                    if day.weekday != 1 {
                        Divider().padding(.leading, 72)
                    }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
            )
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
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        draftName = template.name
                        editingDay = todayWeekday
                    } label: {
                        Text(template.name)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .tracking(0.3)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(
                                LinearGradient(
                                    colors: [Color.accentColor.opacity(0.18), Color.accentColor.opacity(0.10)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: Capsule()
                            )
                            .overlay(Capsule().stroke(Color.accentColor.opacity(0.30), lineWidth: 0.5))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.pressableCard)
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
