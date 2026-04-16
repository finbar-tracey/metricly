import SwiftUI
import SwiftData
import Charts

struct CaffeineTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CaffeineEntry.date, order: .reverse) private var entries: [CaffeineEntry]

    @State private var selectedSource = "Coffee"
    @State private var customMg = ""
    @State private var entryToDelete: CaffeineEntry?
    @FocusState private var isMgFocused: Bool

    // MARK: - Computed

    private func totalRemainingMg(at now: Date) -> Double {
        entries.reduce(0) { $0 + $1.remainingCaffeine(at: now) }
    }

    private func sleepReadiness(_ mg: Double) -> (label: String, color: Color, icon: String) {
        if mg < 25 { return ("Ready for Sleep", .green, "moon.zzz.fill") }
        if mg < 50 { return ("Winding Down", .yellow, "moon.fill") }
        if mg < 100 { return ("Elevated", .orange, "exclamationmark.triangle.fill") }
        return ("Too Stimulated", .red, "bolt.fill")
    }

    private var defaultMgForSource: Double {
        CaffeineEntry.presets.first { $0.name == selectedSource }?.mg ?? 0
    }

    private var effectiveMg: Double {
        if let custom = Double(customMg), custom > 0 { return custom }
        return defaultMgForSource
    }

    private struct DecayPoint: Identifiable {
        let id = UUID()
        let date: Date
        let mg: Double
    }

    private func decayCurveData(from now: Date) -> [DecayPoint] {
        let recentEntries = entries.filter { $0.remainingCaffeine(at: now) > 0.1 }
        return (0...48).map { i in
            let time = now.addingTimeInterval(Double(i) * 900) // 15-min intervals, 12 hours
            let total = recentEntries.reduce(0.0) { $0 + $1.remainingCaffeine(at: time) }
            return DecayPoint(date: time, mg: total)
        }
    }

    // MARK: - Body

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let now = context.date
            let remaining = totalRemainingMg(at: now)
            let readiness = sleepReadiness(remaining)
            List {
                Section {
                    currentStatusView(remaining: remaining, readiness: readiness)
                }

                if remaining > 0.5 {
                    Section("Caffeine Decay") {
                        decayChartView(from: now)
                            .frame(height: 200)
                            .padding(.vertical, 8)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    }
                }

                Section("Log Caffeine") {
                    sourcePickerView
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    mgInputRow
                    logButton
                }

                Section("Recent Intake") {
                    if entries.isEmpty {
                        Text("No caffeine logged yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(entries.prefix(20)) { entry in
                            intakeRow(entry)
                        }
                        .onDelete { offsets in
                            if let index = offsets.first {
                                entryToDelete = Array(entries.prefix(20))[index]
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Caffeine Tracker")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isMgFocused = false }
            }
        }
        .alert("Delete Entry?", isPresented: Binding(
            get: { entryToDelete != nil },
            set: { if !$0 { entryToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let entry = entryToDelete {
                    modelContext.delete(entry)
                    entryToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { entryToDelete = nil }
        } message: {
            Text("Remove this caffeine entry?")
        }
    }

    // MARK: - Current Status

    private func currentStatusView(remaining: Double, readiness: (label: String, color: Color, icon: String)) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: min(1.0, remaining / 400))
                    .stroke(readiness.color.gradient,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.8), value: remaining)
                VStack(spacing: 2) {
                    Text("\(Int(remaining))")
                        .font(.title.bold().monospacedDigit())
                    Text("mg remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 110, height: 110)

            HStack(spacing: 6) {
                Image(systemName: readiness.icon)
                    .foregroundStyle(readiness.color)
                Text(readiness.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(readiness.color)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(readiness.color.opacity(0.1), in: Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Decay Chart

    private func decayChartView(from now: Date) -> some View {
        Chart(decayCurveData(from: now)) { point in
            LineMark(
                x: .value("Time", point.date),
                y: .value("Caffeine", point.mg)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(Color.brown)

            AreaMark(
                x: .value("Time", point.date),
                y: .value("Caffeine", point.mg)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(Color.brown.opacity(0.15).gradient)
        }
        .chartYAxisLabel("mg")
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 3)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour())
            }
        }
    }

    // MARK: - Source Picker

    private var sourcePickerView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(CaffeineEntry.presets, id: \.name) { preset in
                    Button {
                        selectedSource = preset.name
                        if preset.name != "Other" { customMg = "" }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: preset.icon)
                                .font(.system(size: 18))
                            Text(preset.name)
                                .font(.caption2)
                            if preset.mg > 0 {
                                Text("\(Int(preset.mg))mg")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: 70, height: 65)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedSource == preset.name
                                      ? Color.brown.opacity(0.15)
                                      : Color(.systemGray6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedSource == preset.name
                                        ? Color.brown : .clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - mg Input

    private var mgInputRow: some View {
        HStack {
            Text("Amount")
                .foregroundStyle(.secondary)
            Spacer()
            TextField(
                selectedSource == "Other" ? "mg" : "\(Int(defaultMgForSource)) mg",
                text: $customMg
            )
            .keyboardType(.decimalPad)
            .focused($isMgFocused)
            .multilineTextAlignment(.trailing)
            .frame(width: 100)
            Text("mg")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Log Button

    private var logButton: some View {
        Button {
            logCaffeine()
        } label: {
            HStack {
                Spacer()
                Image(systemName: "plus.circle.fill")
                Text("Log \(Int(effectiveMg)) mg \(selectedSource)")
                    .font(.subheadline.bold())
                Spacer()
            }
        }
        .disabled(effectiveMg <= 0)
    }

    // MARK: - Intake Row

    private func intakeRow(_ entry: CaffeineEntry) -> some View {
        HStack {
            let preset = CaffeineEntry.presets.first { $0.name == entry.source }
            Image(systemName: preset?.icon ?? "pill.fill")
                .foregroundStyle(.brown)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.source)
                    .font(.subheadline.weight(.semibold))
                Text(entry.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(entry.milligrams)) mg")
                    .font(.subheadline.bold().monospacedDigit())
                let remaining = entry.remainingCaffeine()
                if remaining > 0.5 {
                    Text("\(Int(remaining)) mg left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Fully metabolized")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
    }

    // MARK: - Actions

    private func logCaffeine() {
        let entry = CaffeineEntry(milligrams: effectiveMg, source: selectedSource)
        modelContext.insert(entry)
        customMg = ""
        isMgFocused = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

#Preview {
    NavigationStack {
        CaffeineTrackerView()
    }
    .modelContainer(for: CaffeineEntry.self, inMemory: true)
}
