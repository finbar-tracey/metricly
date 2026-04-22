import SwiftUI
import SwiftData
import Charts

struct WaterTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WaterEntry.date, order: .reverse) private var allEntries: [WaterEntry]

    @State private var customMl = ""
    @FocusState private var isMlFocused: Bool

    private var todayEntries: [WaterEntry] {
        let start = Calendar.current.startOfDay(for: .now)
        return allEntries.filter { $0.date >= start }
    }

    private var todayTotalMl: Double {
        todayEntries.reduce(0) { $0 + $1.milliliters }
    }

    private var goalMl: Double {
        WaterEntry.defaultGoalMl
    }

    private var progress: Double {
        min(1.0, todayTotalMl / goalMl)
    }

    // Daily totals for last 7 days
    private var dailyTotals: [(date: Date, ml: Double)] {
        let calendar = Calendar.current
        return (0..<7).reversed().compactMap { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: .now) else { return nil }
            let start = calendar.startOfDay(for: date)
            guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
            let total = allEntries.filter { $0.date >= start && $0.date < end }.reduce(0) { $0 + $1.milliliters }
            return (date: start, ml: total)
        }
    }

    var body: some View {
        List {
            // Today's progress
            Section {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(.quaternary, lineWidth: 10)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(Color.cyan.gradient,
                                    style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.6), value: progress)
                        VStack(spacing: 2) {
                            Text("\(Int(todayTotalMl))")
                                .font(.title.bold().monospacedDigit())
                            Text("/ \(Int(goalMl)) ml")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 120, height: 120)

                    if progress >= 1.0 {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Goal reached!")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.green)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(.green.opacity(0.1), in: Capsule())
                    } else {
                        Text("\(Int(goalMl - todayTotalMl)) ml remaining")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            // Quick add
            Section("Log Water") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(WaterEntry.presets, id: \.label) { preset in
                            Button {
                                addEntry(ml: preset.ml)
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: preset.icon)
                                        .font(.system(size: 18))
                                        .foregroundStyle(.cyan)
                                    Text(preset.label)
                                        .font(.caption2)
                                    Text("\(Int(preset.ml)) ml")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 80, height: 65)
                                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                HStack {
                    Text("Custom")
                        .foregroundStyle(.secondary)
                    Spacer()
                    TextField("ml", text: $customMl)
                        .keyboardType(.numberPad)
                        .focused($isMlFocused)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("ml")
                        .foregroundStyle(.secondary)
                    Button {
                        if let ml = Double(customMl), ml > 0 {
                            addEntry(ml: ml)
                            customMl = ""
                            isMlFocused = false
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .disabled(Double(customMl) ?? 0 <= 0)
                }
            }

            // Weekly chart
            if !dailyTotals.isEmpty {
                Section("This Week") {
                    Chart(dailyTotals, id: \.date) { day in
                        BarMark(
                            x: .value("Day", day.date, unit: .day),
                            y: .value("ml", day.ml)
                        )
                        .foregroundStyle(day.ml >= goalMl ? Color.cyan : Color.cyan.opacity(0.5))
                        .cornerRadius(4)

                        RuleMark(y: .value("Goal", goalMl))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                            .foregroundStyle(.cyan.opacity(0.5))
                    }
                    .chartYAxisLabel("ml")
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        }
                    }
                    .frame(height: 160)
                    .padding(.vertical, 8)
                }
            }

            // Today's entries
            Section("Today's Entries") {
                if todayEntries.isEmpty {
                    Text("No water logged today.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(todayEntries) { entry in
                        HStack {
                            Image(systemName: "drop.fill")
                                .foregroundStyle(.cyan)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(Int(entry.milliliters)) ml")
                                    .font(.subheadline.weight(.semibold))
                                Text(entry.date, format: .dateTime.hour().minute())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            modelContext.delete(todayEntries[index])
                        }
                    }
                }
            }
        }
        .navigationTitle("Water Tracker")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isMlFocused = false }
            }
        }
    }

    private func addEntry(ml: Double) {
        let entry = WaterEntry(milliliters: ml)
        modelContext.insert(entry)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

#Preview {
    NavigationStack {
        WaterTrackerView()
    }
    .modelContainer(for: WaterEntry.self, inMemory: true)
}
