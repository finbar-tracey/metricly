import SwiftUI
import SwiftData
import Charts

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

    // MARK: - Constants

    static let benchmarks: [Benchmark] = [
        Benchmark(name: "1 km",     meters: 1_000,    icon: "flag.fill"),
        Benchmark(name: "5 km",     meters: 5_000,    icon: "figure.run"),
        Benchmark(name: "10 km",    meters: 10_000,   icon: "clock.fill"),
        Benchmark(name: "15 km",    meters: 15_000,   icon: "arrow.right.to.line"),
        Benchmark(name: "Half",     meters: 21_097,   icon: "medal.fill"),
        Benchmark(name: "Marathon", meters: 42_195,   icon: "trophy.fill"),
    ]

    // MARK: - State

    @State private var group: ActivityGroup = .runs
    @State private var chartBenchmark: Benchmark? = nil

    // MARK: - Derived data

    private var useKm: Bool { weightUnit.distanceUnit == .km }
    private var distUnit: DistanceUnit { weightUnit.distanceUnit }

    private var sessions: [CardioSession] {
        let types = group.types.map(\.rawValue)
        return allSessions.filter { types.contains($0.cardioType) }
    }

    /// Best time for a given distance, using avg pace × target distance.
    /// Only considers sessions that covered at least 97% of the target (GPS tolerance).
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

    // All-time records
    private var longestSession:       CardioSession? { sessions.max(by: { $0.distanceMeters  < $1.distanceMeters  }) }
    private var fastestPaceSession:   CardioSession? { sessions.filter { $0.distanceMeters > 500 && $0.avgPaceSecPerKm > 0 }.min(by: { $0.avgPaceSecPerKm < $1.avgPaceSecPerKm }) }
    private var longestDuration:      CardioSession? { sessions.max(by: { $0.durationSeconds < $1.durationSeconds }) }
    private var mostElevation:        CardioSession? { sessions.filter { $0.elevationGainMeters > 0 }.max(by: { $0.elevationGainMeters < $1.elevationGainMeters }) }
    private var mostCaloriesSession:  CardioSession? { sessions.filter { ($0.caloriesBurned ?? 0) > 0 }.max(by: { ($0.caloriesBurned ?? 0) < ($1.caloriesBurned ?? 0) }) }
    /// Lowest average heart rate on a run ≥ 5 km — a proxy for aerobic fitness (lower = fitter).
    private var bestAerobicSession:   CardioSession? { sessions.filter { $0.distanceMeters >= 5000 && ($0.avgHeartRate ?? 0) > 40 }.min(by: { ($0.avgHeartRate ?? 999) < ($1.avgHeartRate ?? 999) }) }

    /// Fastest individual km or mile split across all sessions.
    private var fastestSplit: (paceSecPerUnit: Double, session: CardioSession)? {
        var best: (Double, CardioSession)? = nil
        for s in sessions {
            let fastest = s.splits
                .map { useKm ? $0.paceSecondsPerKm : $0.paceSecondsPerMile }
                .filter { $0 > 30 && $0 < 3600 }   // sanity bounds: 30 s/km – 60 min/km
                .min() ?? .greatestFiniteMagnitude
            if fastest < .greatestFiniteMagnitude, best.map({ fastest < $0.0 }) ?? true {
                best = (fastest, s)
            }
        }
        return best.map { ($0.0, $0.1) }
    }

    // Volume records
    struct WeekRecord { let km: Double; let weekStart: Date; let sessionCount: Int }
    struct MonthRecord { let km: Double; let monthStart: Date }

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

    /// Count of sessions (≥ 2 km) where the second half was faster than the first — good pacing discipline.
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

    // Pace trend for the selected (or first available) benchmark
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

    // MARK: - Body

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                // Activity type picker
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
                    emptyState
                } else {
                    benchmarksSection
                    allTimeSection
                    volumeSection
                    if trendPoints.count >= 2 { trendSection }
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

    // MARK: - Benchmarks

    private var benchmarksSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Distance Bests", icon: "flag.checkered", color: group.color)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Self.benchmarks) { bm in
                    benchmarkCard(bm, result: bestFor(bm))
                }
            }
        }
        .appCard()
    }

    @ViewBuilder
    private func benchmarkCard(_ bm: Benchmark, result: BenchmarkResult?) -> some View {
        let achieved = result != nil
        Group {
            if let r = result {
                NavigationLink(destination: CardioSessionDetailView(session: r.session)) {
                    benchmarkCardContent(bm, result: r, achieved: true)
                }
                .buttonStyle(.plain)
            } else {
                benchmarkCardContent(bm, result: nil, achieved: false)
            }
        }
    }

    private func benchmarkCardContent(_ bm: Benchmark, result: BenchmarkResult?, achieved: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: bm.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(achieved ? group.color : .secondary)
                Text(bm.name.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(achieved ? .primary : .secondary)
                    .tracking(0.4)
                Spacer()
            }

            if let r = result {
                Text(r.formattedTime)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(group.color)
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(formatPace(r.paceSecPerKm))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Text(r.date, format: .dateTime.day().month(.abbreviated).year())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                Text("—")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.quaternary)
                Text("No sessions yet")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
                Spacer()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .background(
            achieved
                ? AnyShapeStyle(LinearGradient(
                    colors: [group.color.opacity(0.10), Color(.secondarySystemGroupedBackground)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                : AnyShapeStyle(Color(.secondarySystemGroupedBackground))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(achieved ? group.color.opacity(0.20) : Color.white.opacity(0.05), lineWidth: 0.5)
        )
    }

    // MARK: - All-Time Records

    private var allTimeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "All-Time Records", icon: "trophy.fill", color: .yellow)

            VStack(spacing: 0) {
                if let s = longestSession {
                    recordRow(icon: "ruler",           color: group.color,
                              label: "Longest Distance", value: s.formattedDistance(useKm: useKm),
                              sub: s.date.formatted(.dateTime.day().month(.abbreviated).year()),
                              session: s)
                }
                if let s = fastestPaceSession {
                    Divider().padding(.leading, 54)
                    recordRow(icon: "speedometer",     color: .purple,
                              label: "Fastest Avg Pace", value: s.formattedPace(useKm: useKm),
                              sub: s.formattedDistance(useKm: useKm) + " · " +
                                   s.date.formatted(.dateTime.day().month(.abbreviated).year()),
                              session: s)
                }
                if let split = fastestSplit {
                    Divider().padding(.leading, 54)
                    recordRow(icon: "bolt.fill",       color: .yellow,
                              label: "Fastest \(useKm ? "km" : "mi") Split",
                              value: formatPaceShort(split.paceSecPerUnit) + " /\(useKm ? "km" : "mi")",
                              sub: split.session.date.formatted(.dateTime.day().month(.abbreviated).year()),
                              session: split.session)
                }
                if let s = longestDuration {
                    Divider().padding(.leading, 54)
                    recordRow(icon: "clock.fill",      color: .indigo,
                              label: "Longest Duration", value: s.formattedDuration,
                              sub: s.date.formatted(.dateTime.day().month(.abbreviated).year()),
                              session: s)
                }
                if let s = mostElevation {
                    Divider().padding(.leading, 54)
                    recordRow(icon: "mountain.2.fill", color: .brown,
                              label: "Most Elevation",   value: String(format: "%.0f m", s.elevationGainMeters),
                              sub: s.date.formatted(.dateTime.day().month(.abbreviated).year()),
                              session: s)
                }
                if let s = mostCaloriesSession, let cal = s.caloriesBurned {
                    Divider().padding(.leading, 54)
                    recordRow(icon: "flame.fill",      color: .red,
                              label: "Most Calories",    value: String(format: "%.0f kcal", cal),
                              sub: s.formattedDistance(useKm: useKm) + " · " +
                                   s.date.formatted(.dateTime.day().month(.abbreviated).year()),
                              session: s)
                }
                if let s = bestAerobicSession, let hr = s.avgHeartRate {
                    Divider().padding(.leading, 54)
                    recordRow(icon: "heart.fill",      color: .pink,
                              label: "Lowest HR Run",    value: "\(Int(hr)) bpm",
                              sub: "Aerobic efficiency · " + s.formattedDistance(useKm: useKm),
                              session: s)
                }
            }
            .background(Color(.tertiarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    // MARK: - Volume Records

    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Volume Records", icon: "chart.bar.fill", color: group.color)

            VStack(spacing: 12) {
                // Best week and busiest week side by side
                HStack(spacing: 12) {
                    volumeTile(
                        icon: "calendar.badge.checkmark",
                        color: group.color,
                        label: "Best Week",
                        primary: bestWeek.map { String(format: "%.1f %@", distUnit.display($0.km), distUnit.label) } ?? "—",
                        secondary: bestWeek.map {
                            $0.weekStart.formatted(.dateTime.day().month(.abbreviated)) +
                            " · \($0.sessionCount) session\($0.sessionCount == 1 ? "" : "s")"
                        } ?? "No data yet"
                    )
                    volumeTile(
                        icon: "calendar",
                        color: .teal,
                        label: "Best Month",
                        primary: bestMonth.map { String(format: "%.1f %@", distUnit.display($0.km), distUnit.label) } ?? "—",
                        secondary: bestMonth.map {
                            $0.monthStart.formatted(.dateTime.month(.wide).year())
                        } ?? "No data yet"
                    )
                }

                HStack(spacing: 12) {
                    volumeTile(
                        icon: "repeat",
                        color: .indigo,
                        label: "Most Sessions / Week",
                        primary: busiestWeek.map { "\($0.sessionCount)" } ?? "—",
                        secondary: busiestWeek.map {
                            $0.weekStart.formatted(.dateTime.day().month(.abbreviated)) +
                            " · " + String(format: "%.1f %@", distUnit.display($0.km), distUnit.label)
                        } ?? "No data yet"
                    )
                    let negCount = negativeSplitCount
                    volumeTile(
                        icon: "arrow.down.right",
                        color: .green,
                        label: "Negative Splits",
                        primary: negCount > 0 ? "\(negCount)" : "—",
                        secondary: negCount > 0
                            ? "session\(negCount == 1 ? "" : "s") where 2nd half was faster"
                            : "Finish faster than you start"
                    )
                }
            }
        }
        .appCard()
    }

    private func volumeTile(icon: String, color: Color, label: String, primary: String, secondary: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(color)
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.4)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Text(primary)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(primary == "—" ? Color(.quaternaryLabel) : color)
                .monospacedDigit()
            Text(secondary)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
        .background(
            primary == "—"
                ? AnyShapeStyle(Color(.secondarySystemGroupedBackground))
                : AnyShapeStyle(LinearGradient(
                    colors: [color.opacity(0.10), Color(.secondarySystemGroupedBackground)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(primary == "—" ? Color.white.opacity(0.05) : color.opacity(0.18), lineWidth: 0.5)
        )
    }

    private func recordRow(icon: String, color: Color, label: String,
                           value: String, sub: String, session: CardioSession) -> some View {
        NavigationLink(destination: CardioSessionDetailView(session: session)) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.72)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                        .shadow(color: color.opacity(0.40), radius: 5, y: 2)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text(sub)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(value)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(color)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
        }
        .buttonStyle(.pressableCard)
    }

    // MARK: - Pace Trend

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "Pace Trend", icon: "chart.line.downtrend.xyaxis",
                              color: group.color)
                Spacer()
                Menu {
                    ForEach(Self.benchmarks) { bm in
                        if sessions.contains(where: { $0.distanceMeters >= bm.meters * 0.97 }) {
                            Button {
                                chartBenchmark = bm
                            } label: {
                                if activeBenchmark?.id == bm.id {
                                    Label(bm.name, systemImage: "checkmark")
                                } else {
                                    Text(bm.name)
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(activeBenchmark?.name ?? "")
                            .font(.caption.weight(.semibold))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(group.color)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(group.color.opacity(0.1), in: Capsule())
                }
            }

            // Chart — lower Y = faster pace = shown at bottom; trend going down = improvement
            Chart(trendPoints) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Pace", point.paceSecPerKm)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            group.color.opacity(0.55),
                            group.color.opacity(0.22),
                            group.color.opacity(0.02)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Pace", point.paceSecPerKm)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [group.color, group.color.opacity(0.72)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .shadow(color: group.color.opacity(0.30), radius: 5, y: 2)

                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Pace", point.paceSecPerKm)
                )
                .foregroundStyle(group.color)
                .symbolSize(36)
                .annotation(position: .overlay) {
                    Circle().fill(.white).frame(width: 4, height: 4)
                }
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { val in
                    AxisGridLine().foregroundStyle(Color(.separator).opacity(0.5))
                    AxisValueLabel {
                        if let sec = val.as(Double.self) {
                            Text(formatPaceShort(sec))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(Color(.separator).opacity(0.5))
                    AxisValueLabel(format: .dateTime.month(.abbreviated).year())
                        .font(.caption2)
                }
            }
            .frame(height: 180)

            // Improvement summary
            if let first = trendPoints.first, let last = trendPoints.last,
               abs(first.paceSecPerKm - last.paceSecPerKm) > 5 {
                let delta    = first.paceSecPerKm - last.paceSecPerKm
                let improved = delta > 0
                let absMin   = Int(abs(delta)) / 60
                let absSec   = Int(abs(delta)) % 60
                HStack(spacing: 5) {
                    Image(systemName: improved ? "arrow.down.right.circle.fill" : "arrow.up.right.circle.fill")
                    Text(improved
                         ? "\(absMin):\(String(format: "%02d", absSec)) /\(useKm ? "km" : "mi") faster since your first session"
                         : "\(absMin):\(String(format: "%02d", absSec)) /\(useKm ? "km" : "mi") slower than your first session")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(improved ? .green : .orange)
            }

            Text("Lower pace = faster. Each point is one session.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .appCard()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [group.color.opacity(0.20), group.color.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)
                    .overlay(Circle().stroke(group.color.opacity(0.20), lineWidth: 1))
                Image(systemName: group.icon)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [group.color, group.color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            VStack(spacing: 6) {
                Text("No \(group.rawValue.lowercased()) yet")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text("Complete a session to start tracking your personal bests.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .appCard()
    }

    // MARK: - Helpers

    private func formatPace(_ secPerKm: Double) -> String {
        let pace = useKm ? secPerKm : secPerKm * 1.60934
        guard pace > 0 else { return "--:--" }
        return String(format: "%d:%02d /%@", Int(pace) / 60, Int(pace) % 60, useKm ? "km" : "mi")
    }

    private func formatPaceShort(_ secPerKm: Double) -> String {
        let pace = useKm ? secPerKm : secPerKm * 1.60934
        guard pace > 0 else { return "--" }
        return String(format: "%d:%02d", Int(pace) / 60, Int(pace) % 60)
    }
}
