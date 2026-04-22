import SwiftUI
import SwiftData

struct CreatineTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CreatineEntry.date, order: .reverse) private var entries: [CreatineEntry]

    @State private var dose: Double = CreatineEntry.defaultDose

    private var hasTakenToday: Bool {
        let start = Calendar.current.startOfDay(for: .now)
        return entries.contains { $0.date >= start }
    }

    private var currentStreak: Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: .now)

        // If not taken today, start checking from yesterday
        if !hasTakenToday {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }

        while true {
            let dayStart = checkDate
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
            if entries.contains(where: { $0.date >= dayStart && $0.date < dayEnd }) {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else {
                break
            }
        }
        return streak
    }

    private var longestStreak: Int {
        let calendar = Calendar.current
        let sortedDates = Set(entries.map { calendar.startOfDay(for: $0.date) }).sorted(by: >)
        guard !sortedDates.isEmpty else { return 0 }

        var longest = 1
        var current = 1

        for i in 1..<sortedDates.count {
            let diff = calendar.dateComponents([.day], from: sortedDates[i], to: sortedDates[i - 1]).day ?? 0
            if diff == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }

    // Calendar data: last 28 days
    private var last28Days: [(date: Date, taken: Bool)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (0..<28).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: date) else { return nil }
            let taken = entries.contains { $0.date >= date && $0.date < nextDay }
            return (date: date, taken: taken)
        }
    }

    var body: some View {
        List {
            // Today's status
            Section {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(hasTakenToday ? Color.blue.opacity(0.15) : Color(.systemGray5))
                            .frame(width: 100, height: 100)
                        Image(systemName: hasTakenToday ? "checkmark.circle.fill" : "pill.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(hasTakenToday ? .green : .secondary)
                    }

                    Text(hasTakenToday ? "Taken today" : "Not taken yet")
                        .font(.headline)
                        .foregroundStyle(hasTakenToday ? .green : .secondary)

                    if !hasTakenToday {
                        Button {
                            logCreatine()
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Log \(String(format: "%.0f", dose))g Creatine")
                                    .font(.subheadline.bold())
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            // Dose adjustment
            Section {
                Stepper("Daily dose: \(String(format: "%.0f", dose))g", value: $dose, in: 1...20, step: 1)
            }

            // Streak
            Section("Streak") {
                HStack {
                    VStack(spacing: 4) {
                        Text("\(currentStreak)")
                            .font(.title.bold().monospacedDigit())
                            .foregroundStyle(currentStreak >= 7 ? .blue : .primary)
                        Text("Current")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    Divider().frame(height: 36)

                    VStack(spacing: 4) {
                        Text("\(longestStreak)")
                            .font(.title.bold().monospacedDigit())
                            .foregroundStyle(.blue)
                        Text("Longest")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    Divider().frame(height: 36)

                    VStack(spacing: 4) {
                        Text("\(entries.count)")
                            .font(.title.bold().monospacedDigit())
                        Text("Total Days")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 8)
            }

            // Calendar grid
            Section("Last 28 Days") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                    ForEach(last28Days, id: \.date) { day in
                        VStack(spacing: 2) {
                            Text(day.date, format: .dateTime.day())
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Circle()
                                .fill(day.taken ? Color.blue : Color(.systemGray5))
                                .frame(width: 24, height: 24)
                                .overlay {
                                    if day.taken {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            // Recent history
            Section("Recent History") {
                if entries.isEmpty {
                    Text("No entries yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(entries.prefix(14)) { entry in
                        HStack {
                            Image(systemName: "pill.fill")
                                .foregroundStyle(.blue)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(String(format: "%.0f", entry.grams))g creatine")
                                    .font(.subheadline.weight(.semibold))
                                Text(entry.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .onDelete { offsets in
                        let prefixed = Array(entries.prefix(14))
                        for index in offsets {
                            modelContext.delete(prefixed[index])
                        }
                    }
                }
            }
        }
        .navigationTitle("Creatine Tracker")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func logCreatine() {
        let entry = CreatineEntry(grams: dose)
        modelContext.insert(entry)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

#Preview {
    NavigationStack {
        CreatineTrackerView()
    }
    .modelContainer(for: CreatineEntry.self, inMemory: true)
}
