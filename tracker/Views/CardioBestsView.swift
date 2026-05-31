import SwiftUI
import SwiftData

// MARK: - CardioBestsView

struct CardioBestsView: View {

    @Query(sort: \CardioSession.date, order: .reverse) private var allSessions: [CardioSession]
    @Environment(\.weightUnit) private var weightUnit

    // MARK: - Types

    enum ActivityGroup: String, CaseIterable, Hashable {
        case runs   = "Runs"
        case walks  = "Walks"
        case cycles = "Cycles"

        var types: [CardioType] {
            switch self {
            case .runs:   return [.outdoorRun, .indoorRun]
            case .walks:  return [.outdoorWalk, .indoorWalk]
            case .cycles: return [.outdoorCycle]
            }
        }
        var icon: String {
            switch self {
            case .runs:   return "figure.run"
            case .walks:  return "figure.walk"
            case .cycles: return "figure.outdoor.cycle"
            }
        }
        var color: Color {
            switch self {
            case .runs:   return .orange
            case .walks:  return .green
            case .cycles: return .blue
            }
        }
    }

    struct Benchmark: Identifiable {
        let id   = UUID()
        let name: String
        let meters: Double
        let icon: String
    }

    struct BenchmarkResult {
        let timeSeconds: Double
        let paceSecPerKm: Double
        let date: Date
        let session: CardioSession

        var formattedTime: String {
            let h = Int(timeSeconds) / 3600
            let m = Int(timeSeconds) % 3600 / 60
            let s = Int(timeSeconds) % 60
            return h > 0
                ? String(format: "%d:%02d:%02d", h, m, s)
                : String(format: "%d:%02d", m, s)
        }
    }

    struct PaceTrendPoint: Identifiable {
        let id      = UUID()
        let date: Date
        let paceSecPerKm: Double
        let session: CardioSession
    }

    struct WeekRecord { let km: Double; let weekStart: Date; let sessionCount: Int }
    struct MonthRecord { let km: Double; let monthStart: Date }

    static let benchmarks: [Benchmark] = [
        Benchmark(name: "1 km",     meters: 1_000,    icon: "flag.fill"),
        Benchmark(name: "5 km",     meters: 5_000,    icon: "figure.run"),
        Benchmark(name: "10 km",    meters: 10_000,   icon: "clock.fill"),
        Benchmark(name: "15 km",    meters: 15_000,   icon: "arrow.right.to.line"),
        Benchmark(name: "Half",     meters: 21_097,   icon: "medal.fill"),
        Benchmark(name: "Marathon", meters: 42_195,   icon: "trophy.fill"),
    ]

    @State private var group: ActivityGroup = .runs
    @State private var chartBenchmark: Benchmark? = nil

    private var useKm: Bool { weightUnit.distanceUnit == .km }
    private var distUnit: DistanceUnit { weightUnit.distanceUnit }

    private var sessions: [CardioSession] {
        let types = group.types.map(\.rawValue)
        return allSessions.filter { types.contains($0.cardioType) }
    }

    private func bestFor(_ bm: Benchmark) -> BenchmarkResult? {
        let threshold = bm.meters * 0.97
        return sessions
            .filter { $0.distanceMeters >= threshold && $0.avgPaceSecPerKm > 0 }
            .min(by: { $0.avgPaceSecPerKm < $1.avgPaceSecPerKm })
            .map { s in
                BenchmarkResult(
                    timeSeconds:  s.avgPaceSecPerKm * (bm.meters / 1000),
                    paceSecPerKm: s.avgPaceSecPerKm,
                    date:         s.date,
                    session:      s
                )
            }
    }

    private var longestSession:       CardioSession? { sessions.max(by: { $0.distanceMeters  < $1.distanceMeters  }) }
    private var fastestPaceSession:   CardioSession? { sessions.filter { $0.distanceMeters > 500 && $0.avgPaceSecPerKm > 0 }.min(by: { $0.avgPaceSecPerKm < $1.avgPaceSecPerKm }) }
    private var longestDuration:      CardioSession? { sessions.max(by: { $0.durationSeconds < $1.durationSeconds }) }
    private var mostElevation:        CardioSession? { sessions.filter { $0.elevationGainMeters > 0 }.max(by: { $0.elevationGainMeters < $1.elevationGainMeters }) }
    private var mostCaloriesSession:  CardioSession? { sessions.filter { ($0.caloriesBurned ?? 0) > 0 }.max(by: { ($0.caloriesBurned ?? 0) < ($1.caloriesBurned ?? 0) }) }
    private var bestAerobicSession:   CardioSession? { sessions.filter { $0.distanceMeters >= 5000 && ($0.avgHeartRate ?? 0) > 40 }.min(by: { ($0.avgHeartRate ?? 999) < ($1.avgHeartRate ?? 999) }) }

    private var fastestSplit: (paceSecPerUnit: Double, session: CardioSession)? {
        var best: (Double, CardioSession)? = nil
        for s in sessions {
            let fastest = s.splits
                .map { useKm ? $0.paceSecondsPerKm : $0.paceSecondsPerMile }
                .filter { $0 > 30 && $0 < 3600 }
                .min() ?? .greatestFiniteMagnitude
            if fastest < .greatestFiniteMagnitude, best.map({ fastest < $0.0 }) ?? true {
                best = (fastest, s)
            }
        }
        return best.map { ($0.0, $0.1) }
    }

    private var bestWeek: WeekRecord? {
        var totals: [Date: (km: Double, count: Int)] = [:]
        for s in sessions {
            let start = Calendar.current.dateInterval(of: .weekOfYear, for: s.date)?.start ?? s.date
            totals[start, default: (0, 0)].km    += s.distanceMeters / 1000
            totals[start, default: (0, 0)].count += 1
        }
        guard let best = totals.max(by: { $0.value.km < $1.value.km }) else { return nil }
        return WeekRecord(km: best.value.km, weekStart: best.key, sessionCount: best.value.count)
    }

    private var busiestWeek: WeekRecord? {
        var totals: [Date: (km: Double, count: Int)] = [:]
        for s in sessions {
            let start = Calendar.current.dateInterval(of: .weekOfYear, for: s.date)?.start ?? s.date
            totals[start, default: (0, 0)].km    += s.distanceMeters / 1000
            totals[start, default: (0, 0)].count += 1
        }
        guard let best = totals.max(by: { $0.value.count < $1.value.count }) else { return nil }
        return WeekRecord(km: best.value.km, weekStart: best.key, sessionCount: best.value.count)
    }

    private var bestMonth: MonthRecord? {
        var totals: [Date: Double] = [:]
        for s in sessions {
            let start = Calendar.current.dateInterval(of: .month, for: s.date)?.start ?? s.date
            totals[start, default: 0] += s.distanceMeters / 1000
        }
        guard let best = totals.max(by: { $0.value < $1.value }) else { return nil }
        return MonthRecord(km: best.value, monthStart: best.key)
    }

    private var negativeSplitCount: Int {
        sessions.filter { s in
            guard s.distanceMeters >= 2000, !s.splits.isEmpty else { return false }
            let half = s.distanceMeters / 2
            let firstHalf  = s.splits.filter { $0.cumulativeDistanceMeters <= half }
            let secondHalf = s.splits.filter { $0.cumulativeDistanceMeters >  half }
            let avgFirst  = firstHalf.isEmpty  ? 0 : firstHalf.map(\.paceSecondsPerKm).reduce(0,+)  / Double(firstHalf.count)
            let avgSecond = secondHalf.isEmpty ? 0 : secondHalf.map(\.paceSecondsPerKm).reduce(0,+) / Double(secondHalf.count)
            return avgFirst > 0 && avgSecond > 0 && avgSecond < avgFirst
        }.count
    }

    private var activeBenchmark: Benchmark? {
        chartBenchmark ?? Self.benchmarks.first { bm in sessions.contains { $0.distanceMeters >= bm.meters * 0.97 } }
    }

    private var trendPoints: [PaceTrendPoint] {
        guard let bm = activeBenchmark else { return [] }
        return sessions
            .filter { $0.distanceMeters >= bm.meters * 0.97 && $0.avgPaceSecPerKm > 0 }
            .map    { PaceTrendPoint(date: $0.date, paceSecPerKm: $0.avgPaceSecPerKm, session: $0) }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                HStack {
                    CapsuleSegmentPicker(
                        options: ActivityGroup.allCases,
                        selection: $group,
                        activeColor: group.color
                    )
                    Spacer()
                }
                .onChange(of: group) { _, _ in chartBenchmark = nil }

                if sessions.isEmpty {
                    CardioBestsRecordsSection.emptyState(group: group)
                } else {
                    CardioBestsSummarySection.bestsHero(
                        group: group,
                        longestSession: longestSession,
                        fastestPaceSession: fastestPaceSession,
                        sessionCount: sessions.count,
                        useKm: useKm
                    )
                    CardioBestsSummarySection.benchmarksSection(
                        group: group,
                        items: Self.benchmarks.map { ($0, bestFor($0)) },
                        useKm: useKm
                    )
                    CardioBestsRecordsSection.allTimeSection(
                        group: group,
                        longestSession: longestSession,
                        fastestPaceSession: fastestPaceSession,
                        fastestSplit: fastestSplit,
                        longestDuration: longestDuration,
                        mostElevation: mostElevation,
                        mostCaloriesSession: mostCaloriesSession,
                        bestAerobicSession: bestAerobicSession,
                        useKm: useKm
                    )
                    CardioBestsRecordsSection.volumeSection(
                        group: group,
                        bestWeek: bestWeek,
                        bestMonth: bestMonth,
                        busiestWeek: busiestWeek,
                        negativeSplitCount: negativeSplitCount,
                        distUnit: distUnit
                    )
                    if trendPoints.count >= 2 {
                        CardioBestsRecordsSection.trendSection(
                            group: group,
                            benchmarks: Self.benchmarks,
                            sessions: sessions,
                            activeBenchmark: activeBenchmark,
                            trendPoints: trendPoints,
                            chartBenchmark: $chartBenchmark,
                            useKm: useKm
                        )
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Personal Bests")
        .navigationBarTitleDisplayMode(.large)
    }
}
