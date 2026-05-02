import SwiftUI
import SwiftData
import Charts

struct PersonalRecordsView: View {
    @Query(filter: #Predicate<Workout> { !$0.isTemplate && $0.endTime != nil })
    private var workouts: [Workout]
    @Environment(\.weightUnit) private var unit

    private var records: [PRRecord] {
        struct SessionEntry {
            let name: String
            let date: Date
            let weight: Double
            let reps: Int
            let category: MuscleGroup?
        }
        // First pass: collect all session bests per exercise
        var sessionBests: [String: [SessionEntry]] = [:]
        for workout in workouts {
            for exercise in workout.exercises {
                let workingSets = exercise.sets.filter { !$0.isWarmUp }
                guard let heaviest = workingSets.max(by: { $0.weight < $1.weight }),
                      heaviest.weight > 0 else { continue }
                let key = exercise.name.lowercased()
                sessionBests[key, default: []].append(SessionEntry(
                    name: exercise.name, date: workout.date,
                    weight: heaviest.weight, reps: heaviest.reps, category: exercise.category
                ))
            }
        }
        // Second pass: build running-best history so the chart never dips from deload sessions
        var result: [PRRecord] = []
        for sessions in sessionBests.values {
            let sorted = sessions.sorted { $0.date < $1.date }
            var runningBest: Double = 0
            var history: [(Date, Double)] = []
            for s in sorted {
                runningBest = max(runningBest, s.weight)
                history.append((s.date, runningBest))
            }
            guard let prSession = sorted.last(where: { $0.weight == runningBest }) ?? sorted.last,
                  let first = sorted.first else { continue }
            result.append(PRRecord(
                exerciseName: first.name,
                weight: runningBest,
                reps: prSession.reps,
                date: prSession.date,
                category: prSession.category,
                history: history
            ))
        }
        return result.sorted { $0.weight > $1.weight }
    }

    private var groupedRecords: [(MuscleGroup?, [PRRecord])] {
        let grouped = Dictionary(grouping: records, by: { $0.category })
        return grouped.sorted { ($0.key?.rawValue ?? "ZZZ") < ($1.key?.rawValue ?? "ZZZ") }
    }

    var body: some View {
        Group {
            if records.isEmpty {
                ContentUnavailableView {
                    Label("No Records Yet", systemImage: "trophy")
                } description: {
                    Text("Complete workouts with tracked weights to see your personal records here.")
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: AppTheme.sectionSpacing) {
                        heroCard
                        if records.count >= 3 {
                            topLiftsCard
                        }
                        allRecordsCard
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 36)
                }
                .background(Color(.systemGroupedBackground))
            }
        }
        .navigationTitle("Personal Records")
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Color(red: 0.78, green: 0.60, blue: 0.08), Color.orange.opacity(0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(.white.opacity(0.07))
                .frame(width: 200)
                .offset(x: 160, y: -60)

            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center, spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.20))
                            .frame(width: 60, height: 60)
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(records.count)")
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                        Text("Personal Records")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }

                HStack(spacing: 0) {
                    HeroStatCol(value: "\(records.count)", label: "Exercises")
                    Divider().frame(height: 30).overlay(.white.opacity(0.30))
                    HeroStatCol(value: "\(groupedRecords.count)", label: "Groups")
                    if let heaviest = records.first {
                        Divider().frame(height: 30).overlay(.white.opacity(0.30))
                        HeroStatCol(value: unit.formatShort(heaviest.weight), label: "Heaviest")
                    }
                }
            }
            .padding(20)
        }
        .heroCard()
    }


    // MARK: - Top Lifts Card

    private var topLiftsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Top Lifts", icon: "trophy.fill", color: .yellow)

            VStack(spacing: 0) {
                ForEach(Array(records.prefix(3).enumerated()), id: \.element.id) { idx, record in
                    topLiftRow(record, rank: idx + 1)
                    if idx < 2 {
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    private func topLiftRow(_ record: PRRecord, rank: Int) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(rankColor(rank).opacity(0.15))
                    .frame(width: 40, height: 40)
                Text(rankEmoji(rank))
                    .font(.system(size: 18))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(record.exerciseName)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 4) {
                    Text(unit.format(record.weight))
                        .font(.subheadline.bold())
                        .foregroundStyle(rankColor(rank))
                    Text("× \(record.reps)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(record.date, format: .dateTime.month(.abbreviated).day())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if record.history.count >= 2 {
                sparkline(record.sortedHistory)
                    .frame(width: 60, height: 28)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - All Records Card

    private var allRecordsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "All Records", icon: "list.star", color: .accentColor)

            ForEach(groupedRecords, id: \.0) { group, recs in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        if let group {
                            MuscleIconView(group: group, color: Color.accentColor)
                                .frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "dumbbell")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.accentColor)
                        }
                        Text((group?.rawValue ?? "Uncategorized").uppercased())
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 2)

                    VStack(spacing: 0) {
                        ForEach(Array(recs.enumerated()), id: \.element.id) { idx, record in
                            prRow(record)
                            if idx < recs.count - 1 {
                                Divider().padding(.leading, 56)
                            }
                        }
                    }
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .appCard()
    }

    private func prRow(_ record: PRRecord) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill((record.category?.color ?? Color.accentColor).opacity(0.12))
                    .frame(width: 32, height: 32)
                if let category = record.category {
                    MuscleIconView(group: category, color: category.color)
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: "dumbbell")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(record.exerciseName)
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 4) {
                    Text(unit.format(record.weight))
                        .font(.caption.bold())
                    Text("× \(record.reps)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(record.date, format: .dateTime.month(.abbreviated).day())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if record.history.count >= 2 {
                sparkline(record.sortedHistory)
                    .frame(width: 50, height: 22)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Sparkline

    private func sparkline(_ data: [(Date, Double)]) -> some View {
        Chart(data, id: \.0) { point in
            LineMark(
                x: .value("Date", point.0),
                y: .value("Weight", unit.display(point.1))
            )
            .foregroundStyle(Color.accentColor)
            .interpolationMethod(.catmullRom)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }

    // MARK: - Helpers

    private func rankEmoji(_ rank: Int) -> String {
        switch rank { case 1: return "🥇"; case 2: return "🥈"; default: return "🥉" }
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank { case 1: return .yellow; case 2: return .gray; default: return .brown }
    }
}

// Extension to add color to MuscleGroup
private extension MuscleGroup {
    var color: Color {
        switch self {
        case .chest: return .blue
        case .back: return .indigo
        case .shoulders: return .purple
        case .biceps: return .orange
        case .triceps: return .red
        case .legs: return .green
        case .core: return .teal
        case .cardio: return .pink
        case .other: return .gray
        }
    }
}

struct PRRecord: Identifiable {
    let id = UUID()
    let exerciseName: String
    let weight: Double
    let reps: Int
    let date: Date
    let category: MuscleGroup?
    var history: [(Date, Double)]

    var sortedHistory: [(Date, Double)] { history.sorted { $0.0 < $1.0 } }
}

#Preview {
    NavigationStack { PersonalRecordsView() }
        .modelContainer(for: Workout.self, inMemory: true)
}
