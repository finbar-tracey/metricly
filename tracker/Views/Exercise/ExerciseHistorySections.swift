import SwiftUI
import Charts

enum ExerciseHistorySections {

    struct ChartPoint: Identifiable {
        let id = UUID()
        let date: Date
        let maxWeight: Double
        let estimated1RM: Double
    }

    struct CardioChartPoint: Identifiable {
        let id = UUID()
        let date: Date
        let maxDistance: Double
    }

    static func bestSetCard(
        best: ExerciseSet,
        isCardioExercise: Bool,
        weightUnit: WeightUnit,
        distanceUnit: DistanceUnit,
        estimated1RM: Double?
    ) -> some View {
        ZStack(alignment: .leading) {
            LinearGradient(
                colors: [
                    AppTheme.Signal.amber,
                    Color(red: 0.85, green: 0.42, blue: 0.10),
                    Color(red: 0.65, green: 0.28, blue: 0.30)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            LinearGradient(
                colors: [.white.opacity(0.18), .clear],
                startPoint: .top, endPoint: .center
            )
            .blendMode(.plusLighter)
            Circle().fill(.white.opacity(0.10)).frame(width: 140).blur(radius: 10).offset(x: 230, y: 0)

            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial.opacity(0.7))
                        .frame(width: 52, height: 52)
                        .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.5))
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Personal Best")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.82))
                        .tracking(0.5)
                        .textCase(.uppercase)
                    if isCardioExercise {
                        Text([best.formattedDistance(unit: distanceUnit), best.formattedDuration]
                            .compactMap { $0 }.joined(separator: " in "))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                    } else {
                        Text("\(best.reps) reps @ \(weightUnit.format(best.weight))")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                        if let e1rm = estimated1RM, e1rm > 0 {
                            Text("Est. 1RM: \(weightUnit.format(e1rm))")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                }
                Spacer()
            }
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
        .accessibilityElement(children: .combine)
    }

    static func chartToggle(
        _ title: String,
        value: Bool,
        showEstimated1RM: Binding<Bool>
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) { showEstimated1RM.wrappedValue = value }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background {
                    if showEstimated1RM.wrappedValue == value {
                        Capsule().fill(
                            LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.72)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.accentColor.opacity(0.40), radius: 6, y: 3)
                    } else {
                        Capsule().fill(Color(.secondarySystemFill))
                    }
                }
                .foregroundStyle(showEstimated1RM.wrappedValue == value ? .white : .primary)
        }
        .buttonStyle(.pressableCard)
    }

    static func cardioSessionSets(_ sets: [ExerciseSet], distanceUnit: DistanceUnit) -> some View {
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

    static func strengthSessionSets(_ sets: [ExerciseSet], weightUnit: WeightUnit) -> some View {
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

    static func progressionChart(
        chartData: [ChartPoint],
        showEstimated1RM: Bool,
        weightUnit: WeightUnit,
        chartYDomain: ClosedRange<Double>
    ) -> some View {
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

    static func cardioProgressionChart(
        cardioChartData: [CardioChartPoint],
        distanceUnit: DistanceUnit,
        chartYDomain: ClosedRange<Double>
    ) -> some View {
        Chart(cardioChartData) { point in
            let value = distanceUnit.display(point.maxDistance)
            LineMark(x: .value("Date", point.date, unit: .day), y: .value("Distance", value))
                .interpolationMethod(.catmullRom).foregroundStyle(Color.green)
            PointMark(x: .value("Date", point.date, unit: .day), y: .value("Distance", value))
                .symbolSize(30).foregroundStyle(Color.green)
        }
        .chartYAxisLabel(distanceUnit.label)
        .chartYScale(domain: chartYDomain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Distance progression, \(cardioChartData.count) sessions")
    }

    static func chartData(from history: [Exercise]) -> [ChartPoint] {
        history.reversed().compactMap { exercise in
            guard let date = exercise.workout?.date else { return nil }
            let workingSets = exercise.sets.filter { !$0.isWarmUp }
            let maxW = workingSets.map(\.weight).max() ?? 0
            guard maxW > 0 else { return nil }
            let best1RM = workingSets.map { OneRepMaxEngine.epleyEstimate(weight: $0.weight, reps: $0.reps) }.max() ?? maxW
            return ChartPoint(date: date, maxWeight: maxW, estimated1RM: best1RM)
        }
    }

    static func cardioChartData(from history: [Exercise]) -> [CardioChartPoint] {
        history.reversed().compactMap { exercise in
            guard let date = exercise.workout?.date else { return nil }
            let maxDist = exercise.sets.compactMap(\.distance).max() ?? 0
            guard maxDist > 0 else { return nil }
            return CardioChartPoint(date: date, maxDistance: maxDist)
        }
    }

    static func chartYDomain(chartData: [ChartPoint], showEstimated1RM: Bool, weightUnit: WeightUnit) -> ClosedRange<Double> {
        let weights = chartData.map { weightUnit.display(showEstimated1RM ? $0.estimated1RM : $0.maxWeight) }
        guard let minVal = weights.min(), let maxVal = weights.max() else { return 0...100 }
        let padding = Swift.max(1, (maxVal - minVal) * 0.15)
        return (minVal - padding)...(maxVal + padding)
    }

    static func cardioChartYDomain(cardioChartData: [CardioChartPoint], distanceUnit: DistanceUnit) -> ClosedRange<Double> {
        let distances = cardioChartData.map { distanceUnit.display($0.maxDistance) }
        guard let minVal = distances.min(), let maxVal = distances.max() else { return 0...10 }
        let padding = Swift.max(0.5, (maxVal - minVal) * 0.15)
        return (minVal - padding)...(maxVal + padding)
    }
}
