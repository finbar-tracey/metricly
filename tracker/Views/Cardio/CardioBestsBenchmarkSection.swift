import SwiftUI
import Charts

enum CardioBestsBenchmarkSection {

    static func volumeSection(
        group: CardioBestsView.ActivityGroup,
        bestWeek: CardioBestsView.WeekRecord?,
        bestMonth: CardioBestsView.MonthRecord?,
        busiestWeek: CardioBestsView.WeekRecord?,
        negativeSplitCount: Int,
        distUnit: DistanceUnit
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Volume Records", icon: "chart.bar.fill", color: group.color)

            VStack(spacing: 12) {
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
                    volumeTile(
                        icon: "arrow.down.right",
                        color: .green,
                        label: "Negative Splits",
                        primary: negativeSplitCount > 0 ? "\(negativeSplitCount)" : "—",
                        secondary: negativeSplitCount > 0
                            ? "session\(negativeSplitCount == 1 ? "" : "s") where 2nd half was faster"
                            : "Finish faster than you start"
                    )
                }
            }
        }
        .appCard()
    }

    static func trendSection(
        group: CardioBestsView.ActivityGroup,
        benchmarks: [CardioBestsView.Benchmark],
        sessions: [CardioSession],
        activeBenchmark: CardioBestsView.Benchmark?,
        trendPoints: [CardioBestsView.PaceTrendPoint],
        chartBenchmark: Binding<CardioBestsView.Benchmark?>,
        useKm: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "Pace Trend", icon: "chart.line.downtrend.xyaxis",
                              color: group.color)
                Spacer()
                Menu {
                    ForEach(benchmarks) { bm in
                        if sessions.contains(where: { $0.distanceMeters >= bm.meters * 0.97 }) {
                            Button {
                                chartBenchmark.wrappedValue = bm
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
                    AxisGridLine().foregroundStyle(AppTheme.chartGrid)
                    AxisValueLabel {
                        if let sec = val.as(Double.self) {
                            Text(CardioBestsPRSection.formatPaceShort(sec, useKm: useKm))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(AppTheme.chartGrid)
                    AxisValueLabel(format: .dateTime.month(.abbreviated).year())
                        .font(.caption2)
                }
            }
            .frame(height: 180)

            if let first = trendPoints.first, let last = trendPoints.last,
               abs(first.paceSecPerKm - last.paceSecPerKm) > 5 {
                let delta = first.paceSecPerKm - last.paceSecPerKm
                let improved = delta > 0
                let absMin = Int(abs(delta)) / 60
                let absSec = Int(abs(delta)) % 60
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

    static func emptyState(group: CardioBestsView.ActivityGroup) -> some View {
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

    private static func volumeTile(icon: String, color: Color, label: String, primary: String, secondary: String) -> some View {
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
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.miniCardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.miniCardRadius, style: .continuous)
                .stroke(primary == "—" ? AppTheme.cardHairline : color.opacity(0.18), lineWidth: 0.5)
        )
    }
}
