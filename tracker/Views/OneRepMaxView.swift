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
                                    .background {
                                        if selectedExercise == name {
                                            Capsule().fill(
                                                LinearGradient(
                                                    colors: [.blue, AppTheme.Signal.calm],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                                )
                                            )
                                            .shadow(color: .blue.opacity(0.40), radius: 6, y: 3)
                                        } else {
                                            Capsule().fill(Color(.secondarySystemFill))
                                        }
                                    }
                                    .foregroundStyle(selectedExercise == name ? Color.white : Color.primary)
                            }
                            .buttonStyle(.pressableCard)
                        }
                    }
                }
            }
        }
        .appCard()
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        HeroCard(palette: AppTheme.Gradients.calm) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial.opacity(0.7))
                            .frame(width: 56, height: 56)
                            .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.5))
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedExercise ?? "")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))
                            .tracking(0.5)
                            .textCase(.uppercase)
                            .lineLimit(1)
                        Text(unit.format(currentE1RM))
                            .font(.system(size: 42, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .shadow(color: .black.opacity(0.18), radius: 5, y: 3)
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text("PEAK")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(0.5)
                            .foregroundStyle(.white.opacity(0.78))
                        Text(unit.format(peakE1RM))
                            .font(.subheadline.bold().monospacedDigit())
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 11).padding(.vertical, 8)
                    .background(.ultraThinMaterial.opacity(0.7), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(.white.opacity(0.25), lineWidth: 0.5)
                    )
                }

                HStack(spacing: 0) {
                    HeroStatCol(value: "\(e1rmHistory.count)", label: "Sessions")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 32)
                    HeroStatCol(value: unit.format(currentE1RM), label: "Current")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 32)
                    HeroStatCol(value: unit.format(peakE1RM), label: "Peak")
                }
                .padding(.vertical, 10)
                .background(.ultraThinMaterial.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 0.5)
                )
            }
            .padding(20)
        }
    }


    // MARK: - Chart Card

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Estimated 1RM Trend", icon: "chart.line.uptrend.xyaxis", color: .blue)
            Chart(e1rmHistory, id: \.0) { point in
                AreaMark(x: .value("Date", point.0), y: .value("E1RM", unit.display(point.1)))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.40), Color.blue.opacity(0.16), Color.blue.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                LineMark(x: .value("Date", point.0), y: .value("E1RM", unit.display(point.1)))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue, AppTheme.Signal.calm],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .shadow(color: Color.blue.opacity(0.30), radius: 5, y: 2)
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
                            .background {
                                if formula == f {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(
                                        LinearGradient(
                                            colors: [.blue, AppTheme.Signal.calm],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: .blue.opacity(0.35), radius: 6, y: 3)
                                } else {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(.secondarySystemFill))
                                }
                            }
                            .foregroundStyle(formula == f ? Color.white : Color.primary)
                    }
                    .buttonStyle(.pressableCard)
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
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [zoneColor(idx), zoneColor(idx).opacity(0.72)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 40, height: 40)
                                .shadow(color: zoneColor(idx).opacity(0.40), radius: 5, y: 2)
                            Text(row.label)
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        Text(zoneLabel(idx))
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                        Spacer()
                        Text(unit.format(row.value))
                            .font(.system(size: 15, weight: .black, design: .rounded).monospacedDigit())
                            .foregroundStyle(zoneColor(idx))
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    if idx < percentageRows.count - 1 { Divider().padding(.leading, 70) }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.cardHairline, lineWidth: 0.5)
            )
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
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.26), Color.blue.opacity(0.12)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .overlay(Circle().stroke(Color.blue.opacity(0.28), lineWidth: 0.5))
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
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.26), Color.blue.opacity(0.12)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)
                    .overlay(Circle().stroke(Color.blue.opacity(0.28), lineWidth: 0.5))
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
