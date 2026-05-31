import SwiftUI

/// Summary hero and distance benchmark grid for Personal Bests.
enum CardioBestsSummarySection {

    static func bestsHero(
        group: CardioBestsView.ActivityGroup,
        longestSession: CardioSession?,
        fastestPaceSession: CardioSession?,
        sessionCount: Int,
        useKm: Bool
    ) -> some View {
        HeroCard(palette: [group.color, group.color.opacity(0.72), group.color.opacity(0.55)]) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("\(group.rawValue) · Personal Bests")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .tracking(0.5)
                        .textCase(.uppercase)
                }
                HStack(spacing: 0) {
                    HeroStatCol(value: longestSession?.formattedDistance(useKm: useKm) ?? "—", label: "Longest")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 40)
                    HeroStatCol(
                        value: fastestPaceSession.map { formatPaceShort($0.avgPaceSecPerKm, useKm: useKm) } ?? "—",
                        label: "Best Pace"
                    )
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 40)
                    HeroStatCol(value: "\(sessionCount)", label: group.rawValue)
                }
                .padding(.vertical, 12)
                .background(.ultraThinMaterial.opacity(0.55), in: RoundedRectangle(cornerRadius: AppTheme.miniCardRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.miniCardRadius, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 0.5)
                )
            }
            .padding(20)
        }
        .frame(minHeight: 130)
    }

    static func benchmarksSection(
        group: CardioBestsView.ActivityGroup,
        items: [(benchmark: CardioBestsView.Benchmark, result: CardioBestsView.BenchmarkResult?)],
        useKm: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Distance Bests", icon: "flag.checkered", color: group.color)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(items, id: \.benchmark.id) { item in
                    benchmarkCard(group: group, bm: item.benchmark, result: item.result, useKm: useKm)
                }
            }
        }
        .appCard()
    }

    // MARK: - Private

    @ViewBuilder
    private static func benchmarkCard(
        group: CardioBestsView.ActivityGroup,
        bm: CardioBestsView.Benchmark,
        result: CardioBestsView.BenchmarkResult?,
        useKm: Bool
    ) -> some View {
        Group {
            if let r = result {
                NavigationLink(destination: CardioSessionDetailView(session: r.session)) {
                    benchmarkCardContent(group: group, bm: bm, result: r, achieved: true, useKm: useKm)
                }
                .buttonStyle(.plain)
            } else {
                benchmarkCardContent(group: group, bm: bm, result: nil, achieved: false, useKm: useKm)
            }
        }
    }

    private static func benchmarkCardContent(
        group: CardioBestsView.ActivityGroup,
        bm: CardioBestsView.Benchmark,
        result: CardioBestsView.BenchmarkResult?,
        achieved: Bool,
        useKm: Bool
    ) -> some View {
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
                Text(formatPace(r.paceSecPerKm, useKm: useKm))
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
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.miniCardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.miniCardRadius, style: .continuous)
                .stroke(achieved ? group.color.opacity(0.20) : AppTheme.cardHairline, lineWidth: 0.5)
        )
    }

    private static func formatPace(_ secPerKm: Double, useKm: Bool) -> String {
        let pace = useKm ? secPerKm : secPerKm * 1.60934
        guard pace > 0 else { return "--:--" }
        return String(format: "%d:%02d /%@", Int(pace) / 60, Int(pace) % 60, useKm ? "km" : "mi")
    }

    private static func formatPaceShort(_ secPerKm: Double, useKm: Bool) -> String {
        let pace = useKm ? secPerKm : secPerKm * 1.60934
        guard pace > 0 else { return "--" }
        return String(format: "%d:%02d", Int(pace) / 60, Int(pace) % 60)
    }
}
