import SwiftUI
import SwiftData
import Charts

struct OneRepMaxView: View {
    @Query(filter: #Predicate<Workout> { !$0.isTemplate && $0.endTime != nil },
           sort: \Workout.date)
    private var workouts: [Workout]
    @Environment(\.weightUnit) private var unit

    @State private var selectedExercise: String?
    @State private var formula: E1RMFormula = .epley

    enum E1RMFormula: String, CaseIterable {
        case epley = "Epley"
        case brzycki = "Brzycki"

        func calculate(weight: Double, reps: Int) -> Double {
            guard reps > 0, weight > 0 else { return 0 }
            if reps == 1 { return weight }
            switch self {
            case .epley:
                return weight * (1 + Double(reps) / 30.0)
            case .brzycki:
                return weight * (36.0 / (37.0 - Double(reps)))
            }
        }
    }

    private var exerciseNames: [String] {
        var names: [String: Double] = [:]
        for workout in workouts {
            for exercise in workout.exercises {
                let workingSets = exercise.sets.filter { !$0.isWarmUp && $0.weight > 0 }
                guard !workingSets.isEmpty else { continue }
                let maxWeight = workingSets.map(\.weight).max() ?? 0
                names[exercise.name] = max(names[exercise.name] ?? 0, maxWeight)
            }
        }
        return names.sorted { $0.value > $1.value }.map(\.key)
    }

    private var e1rmHistory: [(Date, Double)] {
        guard let name = selectedExercise else { return [] }
        var history: [(Date, Double)] = []
        for workout in workouts {
            for exercise in workout.exercises where exercise.name == name {
                let workingSets = exercise.sets.filter { !$0.isWarmUp && $0.weight > 0 }
                guard !workingSets.isEmpty else { continue }
                let best = workingSets.map { formula.calculate(weight: $0.weight, reps: $0.reps) }.max() ?? 0
                if best > 0 { history.append((workout.date, best)) }
            }
        }
        return history.sorted { $0.0 < $1.0 }
    }

    private var currentE1RM: Double { e1rmHistory.last?.1 ?? 0 }
    private var peakE1RM: Double { e1rmHistory.map(\.1).max() ?? 0 }

    private var percentageRows: [(label: String, value: Double)] {
        let base = currentE1RM
        guard base > 0 else { return [] }
        return [100, 95, 90, 85, 80, 75, 70, 65, 60].map { pct in
            ("\(pct)%", base * Double(pct) / 100.0)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                exercisePickerCard

                if selectedExercise != nil && !e1rmHistory.isEmpty {
                    heroCard
                    chartCard
                    formulaCard
                    percentageCard
                } else if selectedExercise != nil {
                    emptyExerciseCard
                } else if exerciseNames.isEmpty {
                    noDataCard
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Estimated 1RM")
        .onAppear {
            if selectedExercise == nil { selectedExercise = exerciseNames.first }
        }
    }

    // MARK: - Exercise Picker Card

    private var exercisePickerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Exercise", icon: "dumbbell.fill", color: .blue)

            if exerciseNames.isEmpty {
                Text("Complete some workouts to see estimated 1RM data.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(exerciseNames.prefix(20), id: \.self) { name in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedExercise = name
                                }
                            } label: {
                                Text(name)
                                    .font(.caption.bold())
                                    .lineLimit(1)
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(selectedExercise == name ? Color.blue : Color(.secondarySystemFill),
                                                in: Capsule())
                                    .foregroundStyle(selectedExercise == name ? Color.white : Color.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .appCard()
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color.blue, Color.cyan.opacity(0.7)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(.white.opacity(0.07)).frame(width: 200).offset(x: 160, y: -60)

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle().fill(.white.opacity(0.20)).frame(width: 52, height: 52)
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(selectedExercise ?? "")
                            .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.75))
                            .lineLimit(1)
                        Text(unit.format(currentE1RM))
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundStyle(.white).monospacedDigit()
                    }
                    Spacer()
                    VStack(spacing: 3) {
                        Text("Peak").font(.caption2).foregroundStyle(.white.opacity(0.70))
                        Text(unit.format(peakE1RM))
                            .font(.subheadline.bold()).foregroundStyle(.white).monospacedDigit()
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(.white.opacity(0.20), in: RoundedRectangle(cornerRadius: 10))
                }

                HStack(spacing: 0) {
                    heroStatCol("Sessions", value: "\(e1rmHistory.count)")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 28)
                    heroStatCol("Current", value: unit.format(currentE1RM))
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 28)
                    heroStatCol("Peak", value: unit.format(peakE1RM))
                }
            }
            .padding(20)
        }
        .heroCard()
    }

    private func heroStatCol(_ title: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white).monospacedDigit()
            Text(title).font(.caption2).foregroundStyle(.white.opacity(0.70))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Chart Card

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Estimated 1RM Trend", icon: "chart.line.uptrend.xyaxis", color: .blue)
            Chart(e1rmHistory, id: \.0) { point in
                LineMark(x: .value("Date", point.0), y: .value("E1RM", unit.display(point.1)))
                    .foregroundStyle(Color.blue).interpolationMethod(.catmullRom)
                AreaMark(x: .value("Date", point.0), y: .value("E1RM", unit.display(point.1)))
                    .foregroundStyle(Color.blue.opacity(0.12).gradient).interpolationMethod(.catmullRom)
                PointMark(x: .value("Date", point.0), y: .value("E1RM", unit.display(point.1)))
                    .foregroundStyle(Color.blue).symbolSize(25)
            }
            .chartYAxisLabel(unit.label)
            .frame(height: 200)
            .padding(.vertical, 4)
        }
        .appCard()
    }

    // MARK: - Formula Card

    private var formulaCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Formula", icon: "function", color: .blue)

            HStack(spacing: 8) {
                ForEach(E1RMFormula.allCases, id: \.self) { f in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { formula = f }
                    } label: {
                        Text(f.rawValue)
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(formula == f ? Color.blue : Color(.secondarySystemFill),
                                        in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(formula == f ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(formula == .epley
                 ? "Epley: weight × (1 + reps/30). Best for 1–10 rep ranges."
                 : "Brzycki: weight × 36/(37 − reps). Most accurate for lower rep sets.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .appCard()
    }

    // MARK: - Percentage Card

    private var percentageCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Training Zones", icon: "percent", color: .blue)

            VStack(spacing: 0) {
                ForEach(Array(percentageRows.enumerated()), id: \.offset) { idx, row in
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(zoneColor(idx).opacity(0.12))
                                .frame(width: 34, height: 34)
                            Text(row.label)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(zoneColor(idx))
                        }
                        Text(zoneLabel(idx)).font(.subheadline.weight(.medium))
                        Spacer()
                        Text(unit.format(row.value))
                            .font(.subheadline.bold().monospacedDigit())
                    }
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    if idx < percentageRows.count - 1 { Divider().padding(.leading, 62) }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    private func zoneColor(_ index: Int) -> Color {
        [Color.blue, .cyan, .green, .green, .yellow, .orange, .orange, .red, .red][min(index, 8)]
    }

    private func zoneLabel(_ index: Int) -> String {
        ["Max", "Strength", "Strength", "Hypertrophy", "Hypertrophy", "Endurance", "Endurance", "Warm-up", "Warm-up"][min(index, 8)]
    }

    // MARK: - Empty / No Data

    private var emptyExerciseCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Color.blue.opacity(0.12)).frame(width: 60, height: 60)
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 24, weight: .semibold)).foregroundStyle(.blue)
            }
            Text("No data for this exercise yet.")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 32)
        .appCard()
    }

    private var noDataCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Color.blue.opacity(0.12)).frame(width: 70, height: 70)
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 28, weight: .semibold)).foregroundStyle(.blue)
            }
            VStack(spacing: 6) {
                Text("No Workout Data").font(.headline)
                Text("Complete some workouts to calculate your estimated 1RM.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
        .appCard()
    }
}

#Preview {
    NavigationStack { OneRepMaxView() }
        .modelContainer(for: Workout.self, inMemory: true)
}
