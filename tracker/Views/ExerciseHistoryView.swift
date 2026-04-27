import SwiftUI
import SwiftData
import Charts

struct ExerciseHistoryView: View {
    @Environment(\.weightUnit) private var weightUnit
    @Query private var allExercises: [Exercise]
    let exerciseName: String
    @State private var showEstimated1RM = false
    @State private var sortOrder: HistorySortOrder = .date

    private enum HistorySortOrder: String, CaseIterable {
        case date = "Date"
        case weight = "Weight"
        case reps = "Reps"
    }

    private enum CardioSortOrder: String, CaseIterable {
        case date = "Date"
        case distance = "Distance"
        case duration = "Duration"
    }

    @State private var cardioSortOrder: CardioSortOrder = .date

    private var history: [Exercise] {
        allExercises
            .filter { $0.name == exerciseName && !(($0.workout?.isTemplate) ?? true) && !$0.sets.isEmpty }
            .sorted { ($0.workout?.date ?? .distantPast) > ($1.workout?.date ?? .distantPast) }
    }

    private var isCardioExercise: Bool { history.first?.category == .cardio }
    private var distanceUnit: DistanceUnit { weightUnit.distanceUnit }

    private var sortedHistory: [Exercise] {
        if isCardioExercise {
            switch cardioSortOrder {
            case .date: return history
            case .distance: return history.sorted { ($0.sets.compactMap(\.distance).max() ?? 0) > ($1.sets.compactMap(\.distance).max() ?? 0) }
            case .duration: return history.sorted { ($0.sets.compactMap(\.durationSeconds).max() ?? 0) > ($1.sets.compactMap(\.durationSeconds).max() ?? 0) }
            }
        } else {
            switch sortOrder {
            case .date: return history
            case .weight: return history.sorted { ($0.sets.map(\.weight).max() ?? 0) > ($1.sets.map(\.weight).max() ?? 0) }
            case .reps: return history.sorted { ($0.sets.map(\.reps).max() ?? 0) > ($1.sets.map(\.reps).max() ?? 0) }
            }
        }
    }

    private var bestSet: ExerciseSet? {
        let allSets = history.flatMap(\.sets)
        if isCardioExercise { return allSets.max { ($0.distance ?? 0) < ($1.distance ?? 0) } }
        return allSets.max { $0.weight < $1.weight }
    }

    private var progressionRecommendation: ProgressionRecommendation? {
        guard !isCardioExercise else { return nil }
        let sessions = ProgressionAdvisor.buildSessions(from: history)
        guard sessions.count >= 2 else { return nil }
        let rec = ProgressionAdvisor.recommend(sessions: sessions, muscleGroup: history.first?.category)
        if case .insufficient = rec.action { return nil }
        return rec
    }

    var body: some View {
        List {
            ExerciseGuideSectionView(exerciseName: exerciseName)

            if let rec = progressionRecommendation {
                Section { ProgressionBannerView(recommendation: rec) }
            }

            if let best = bestSet {
                Section {
                    bestSetCard(best)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }

            if isCardioExercise {
                if cardioChartData.count >= 2 {
                    Section {
                        cardioProgressionChart
                            .frame(height: 200).padding(.vertical, 8)
                    } header: { Text("Progression") }
                }
            } else {
                if chartData.count >= 2 {
                    Section {
                        HStack(spacing: 6) {
                            chartToggle("Max Weight", value: false)
                            chartToggle("Est. 1RM", value: true)
                            Spacer()
                        }
                        .listRowSeparator(.hidden)
                        progressionChart.frame(height: 200).padding(.vertical, 8)
                    } header: { Text("Progression") }
                }
            }

            Section {
                if history.isEmpty {
                    Text("No history yet for this exercise.").foregroundStyle(.secondary)
                } else {
                    ForEach(sortedHistory.prefix(10)) { exercise in
                        VStack(alignment: .leading, spacing: 6) {
                            if let date = exercise.workout?.date {
                                Text(date, format: .dateTime.weekday(.wide).month().day())
                                    .font(.subheadline.weight(.semibold))
                            }
                            if isCardioExercise {
                                cardioSessionSets(exercise.sets)
                            } else {
                                strengthSessionSets(exercise.sets)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                HStack {
                    Text("Recent Sessions")
                    Spacer()
                    if isCardioExercise {
                        Menu {
                            Picker("Sort", selection: $cardioSortOrder) {
                                ForEach(CardioSortOrder.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                            }
                        } label: {
                            Label("Sort", systemImage: "arrow.up.arrow.down").font(.caption).textCase(nil)
                        }
                    } else {
                        Menu {
                            Picker("Sort", selection: $sortOrder) {
                                ForEach(HistorySortOrder.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                            }
                        } label: {
                            Label("Sort", systemImage: "arrow.up.arrow.down").font(.caption).textCase(nil)
                        }
                    }
                }
            }
        }
        .navigationTitle(exerciseName)
        .navigationDestination(for: FormGuideDestination.self) { dest in
            ExerciseGuideView(exerciseName: dest.exerciseName)
        }
    }

    // MARK: - Best Set Card

    private func bestSetCard(_ best: ExerciseSet) -> some View {
        ZStack(alignment: .leading) {
            LinearGradient(colors: [Color.orange, Color.orange.opacity(0.65)],
                           startPoint: .leading, endPoint: .trailing)
            Circle().fill(.white.opacity(0.08)).frame(width: 140).offset(x: 230, y: 0)
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(.white.opacity(0.20)).frame(width: 48, height: 48)
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Personal Best")
                        .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.75))
                    if isCardioExercise {
                        Text([best.formattedDistance(unit: distanceUnit), best.formattedDuration]
                            .compactMap { $0 }.joined(separator: " in "))
                            .font(.title3.bold()).foregroundStyle(.white)
                    } else {
                        Text("\(best.reps) reps @ \(weightUnit.format(best.weight))")
                            .font(.title3.bold()).foregroundStyle(.white)
                        if let e1rm = currentEstimated1RM, e1rm > 0 {
                            Text("Est. 1RM: \(weightUnit.format(e1rm))")
                                .font(.caption).foregroundStyle(.white.opacity(0.80))
                        }
                    }
                }
                Spacer()
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }

    private func chartToggle(_ title: String, value: Bool) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showEstimated1RM = value }
        } label: {
            Text(title)
                .font(.caption.bold())
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(showEstimated1RM == value ? Color.accentColor : Color(.secondarySystemFill), in: Capsule())
                .foregroundStyle(showEstimated1RM == value ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Session Sets

    private func cardioSessionSets(_ sets: [ExerciseSet]) -> some View {
        HStack(spacing: 12) {
            ForEach(Array(sets.enumerated()), id: \.offset) { index, s in
                VStack(spacing: 2) {
                    if let dist = s.formattedDistance(unit: distanceUnit) { Text(dist).font(.headline) }
                    if let dur = s.formattedDuration { Text(dur).font(.caption).foregroundStyle(.secondary) }
                }
                .frame(minWidth: 54).padding(.vertical, 4).padding(.horizontal, 6)
                .background(.fill, in: .rect(cornerRadius: 8))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Entry \(index + 1): \([s.formattedDistance(unit: distanceUnit), s.formattedDuration].compactMap { $0 }.joined(separator: " in "))")
            }
        }
    }

    private func strengthSessionSets(_ sets: [ExerciseSet]) -> some View {
        HStack(spacing: 12) {
            ForEach(Array(sets.enumerated()), id: \.offset) { index, s in
                VStack {
                    Text("\(s.reps)").font(.headline)
                    Text(weightUnit.formatShort(s.weight)).font(.caption).foregroundStyle(.secondary)
                }
                .frame(minWidth: 44).padding(.vertical, 4).padding(.horizontal, 6)
                .background(.fill, in: .rect(cornerRadius: 8))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Set \(index + 1): \(s.reps) reps at \(weightUnit.format(s.weight))")
            }
        }
    }

    // MARK: - Strength Progression Chart

    private struct ChartPoint: Identifiable {
        let id = UUID()
        let date: Date
        let maxWeight: Double
        let estimated1RM: Double
    }

    private func estimated1RM(weight: Double, reps: Int) -> Double {
        guard reps > 0 else { return weight }
        if reps == 1 { return weight }
        return weight * (1.0 + Double(reps) / 30.0)
    }

    private var chartData: [ChartPoint] {
        history.reversed().compactMap { exercise in
            guard let date = exercise.workout?.date else { return nil }
            let workingSets = exercise.sets.filter { !$0.isWarmUp }
            let maxW = workingSets.map(\.weight).max() ?? 0
            guard maxW > 0 else { return nil }
            let best1RM = workingSets.map { estimated1RM(weight: $0.weight, reps: $0.reps) }.max() ?? maxW
            return ChartPoint(date: date, maxWeight: maxW, estimated1RM: best1RM)
        }
    }

    private var currentEstimated1RM: Double? { chartData.last?.estimated1RM }

    private var progressionChart: some View {
        Chart(chartData) { point in
            let value = showEstimated1RM ? point.estimated1RM : point.maxWeight
            LineMark(x: .value("Date", point.date, unit: .day),
                     y: .value("Weight", weightUnit.display(value)))
                .interpolationMethod(.catmullRom)
                .foregroundStyle(showEstimated1RM ? Color.purple : Color.accentColor)
            PointMark(x: .value("Date", point.date, unit: .day),
                      y: .value("Weight", weightUnit.display(value)))
                .symbolSize(30)
                .foregroundStyle(showEstimated1RM ? Color.purple : Color.accentColor)
        }
        .chartYAxisLabel(weightUnit.label)
        .chartYScale(domain: chartYDomain)
        .animation(.easeInOut(duration: 0.3), value: showEstimated1RM)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(showEstimated1RM ? "Estimated 1RM" : "Weight") progression, \(chartData.count) sessions")
    }

    private var chartYDomain: ClosedRange<Double> {
        let weights = chartData.map { weightUnit.display(showEstimated1RM ? $0.estimated1RM : $0.maxWeight) }
        guard let minVal = weights.min(), let maxVal = weights.max() else { return 0...100 }
        let padding = Swift.max(1, (maxVal - minVal) * 0.15)
        return (minVal - padding)...(maxVal + padding)
    }

    // MARK: - Cardio Progression Chart

    private struct CardioChartPoint: Identifiable {
        let id = UUID()
        let date: Date
        let maxDistance: Double
    }

    private var cardioChartData: [CardioChartPoint] {
        history.reversed().compactMap { exercise in
            guard let date = exercise.workout?.date else { return nil }
            let maxDist = exercise.sets.compactMap(\.distance).max() ?? 0
            guard maxDist > 0 else { return nil }
            return CardioChartPoint(date: date, maxDistance: maxDist)
        }
    }

    private var cardioProgressionChart: some View {
        Chart(cardioChartData) { point in
            let value = distanceUnit.display(point.maxDistance)
            LineMark(x: .value("Date", point.date, unit: .day), y: .value("Distance", value))
                .interpolationMethod(.catmullRom).foregroundStyle(Color.green)
            PointMark(x: .value("Date", point.date, unit: .day), y: .value("Distance", value))
                .symbolSize(30).foregroundStyle(Color.green)
        }
        .chartYAxisLabel(distanceUnit.label)
        .chartYScale(domain: cardioChartYDomain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Distance progression, \(cardioChartData.count) sessions")
    }

    private var cardioChartYDomain: ClosedRange<Double> {
        let distances = cardioChartData.map { distanceUnit.display($0.maxDistance) }
        guard let minVal = distances.min(), let maxVal = distances.max() else { return 0...10 }
        let padding = Swift.max(0.5, (maxVal - minVal) * 0.15)
        return (minVal - padding)...(maxVal + padding)
    }
}
