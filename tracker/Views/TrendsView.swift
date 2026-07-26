import SwiftUI
import SwiftData

/// History & Trends (design_handoff_app, screen-history.jsx) — the "See the
/// trend" destination. Charts draw themselves in: volume bars grow up, the HRV
/// line traces across, the headline stats count up. Falls to a "Day one." empty
/// state before any session exists.
///
/// The richer card-based `InsightsView` (patterns, muscles, recent) stays one
/// tap away via the footer link, so making Trends the primary surface loses
/// nothing.
struct TrendsView: View {
    @Environment(\.weightUnit) private var weightUnit
    @Environment(\.appServices) private var appServices

    @Query(filter: #Predicate<Workout> { !$0.isTemplate && $0.endTime != nil }, sort: \Workout.date, order: .reverse)
    private var finishedWorkouts: [Workout]
    @Query(sort: \CardioSession.date, order: .reverse) private var cardioSessions: [CardioSession]
    @Query private var settingsArray: [UserSettings]

    @State private var hrvSeries: [Double] = []

    private var data: TrendsData {
        TrendsData.build(
            finishedWorkouts: finishedWorkouts,
            currentStreak: Workout.currentStreak(from: finishedWorkouts, cardioSessions: Array(cardioSessions.prefix(60))),
            weightUnit: weightUnit
        )
    }

    private var healthKitEnabled: Bool {
        settingsArray.first?.healthKitEnabled ?? false
    }

    var body: some View {
        ScrollView {
            if data.isEmpty {
                EmptyTrendsContent()
            } else {
                content
            }
        }
        .background(AppTheme.Dark.bg.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .navigationTitle("Trends")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.Dark.bg, for: .navigationBar)
        .task {
            guard healthKitEnabled, hrvSeries.isEmpty else { return }
            if let series = try? await appServices.healthDataCache.fetchDailyHRV(days: 21) {
                hrvSeries = series.map(\.ms)
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            title
            statGrid
            weeklyVolume
            if hrvSeries.count >= 2 {
                hrvTrajectory
            }
            if !data.recentPRs.isEmpty {
                recentPRs
            }
            insightsLink
        }
        .padding(.bottom, 28)
    }

    // MARK: - Title

    private var title: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(data.verdictA)
                    .foregroundStyle(AppTheme.Dark.text)
                Text(data.verdictB)
                    .foregroundStyle(AppTheme.Dark.Signal.recovery)
            }
            .font(.system(size: 30, weight: .bold, design: .rounded))
            .tracking(-1.2)
            Text(data.subline)
                .font(.system(size: 12.5))
                .foregroundStyle(AppTheme.Dark.text3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 14)
    }

    // MARK: - Stat grid

    private var statGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
            spacing: 10
        ) {
            ForEach(data.stats) { stat in
                statTile(stat)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
    }

    private func statTile(_ stat: TrendsData.Stat) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(stat.label)
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(AppTheme.Dark.text4)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                CountUpNumber(target: stat.value, decimals: stat.decimals)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .tracking(-1)
                    .foregroundStyle(stat.tone)
                    .monospacedDigit()
                Text(stat.unit)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(AppTheme.Dark.text3)
            }
            Text(stat.sub)
                .font(.system(size: 9, design: .monospaced))
                .tracking(0.3)
                .foregroundStyle(AppTheme.Dark.text3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .darkCard(radius: 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stat.label): \(stat.spokenValue) \(stat.unit), \(stat.sub)")
    }

    // MARK: - Weekly volume

    private var weeklyVolume: some View {
        section(title: "WEEKLY VOLUME", right: weightUnit == .kg ? "k·kg lifted" : "k·lb lifted") {
            let maxVolume = max(0.01, data.weeklyVolume.map(\.volumeK).max() ?? 0)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(data.weeklyVolume.enumerated()), id: \.element.id) { index, week in
                    volumeBar(week, maxVolume: maxVolume, index: index)
                }
            }
            .frame(height: 92, alignment: .bottom)
        }
    }

    private func volumeBar(_ week: TrendsData.WeekBar, maxVolume: Double, index: Int) -> some View {
        VStack(spacing: 3) {
            Text(week.volumeK, format: .number.precision(.fractionLength(0)))
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(week.isCurrent ? AppTheme.Dark.Signal.recovery : AppTheme.Dark.text4)
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(week.isCurrent
                      ? AnyShapeStyle(LinearGradient(colors: [AppTheme.Dark.Signal.recovery, AppTheme.Dark.Signal.recovery.opacity(0.9)], startPoint: .top, endPoint: .bottom))
                      : AnyShapeStyle(TrendsPalette.pastWeek))
                .frame(height: max(4, CGFloat(week.volumeK / maxVolume) * 76))
                .signalGlow(week.isCurrent ? AppTheme.Dark.Signal.recovery : .clear, radius: 10)
                .growIn(delay: Double(index) * 0.07)
            Text(week.isCurrent ? "NOW" : " ")
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppTheme.Dark.text2)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(week.isCurrent ? "This week" : "Week"): \(String(format: "%.0f", week.volumeK)) thousand")
    }

    // MARK: - HRV trajectory

    private var hrvTrajectory: some View {
        let lo = hrvSeries.min() ?? 0
        let hi = hrvSeries.max() ?? 0
        return section(
            title: "HRV TRAJECTORY · \(hrvSeries.count) DAY",
            right: "\(Int(lo)) → \(Int(hi)) ms"
        ) {
            VStack(spacing: 8) {
                TrajectoryLine(values: hrvSeries, accent: AppTheme.Dark.Signal.recovery)
                    .frame(height: 74)
                HStack {
                    Text("\(hrvSeries.count) DAYS AGO")
                        .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppTheme.Dark.text4)
                    Spacer()
                    let delta = (hrvSeries.last ?? 0) - (hrvSeries.first ?? 0)
                    Text("\(delta >= 0 ? "+" : "")\(Int(delta)) ms · \(delta >= 0 ? "BASELINE RISING" : "EASED OFF")")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(delta >= 0 ? AppTheme.Dark.Signal.recovery : AppTheme.Dark.Signal.caution)
                }
            }
            .padding(14)
            .darkCard(radius: 16)
        }
    }

    // MARK: - Recent PRs

    private var recentPRs: some View {
        section(title: "RECENT PRs", right: "\(data.recentPRs.count) RECENT") {
            VStack(spacing: 0) {
                ForEach(Array(data.recentPRs.enumerated()), id: \.element.id) { index, pr in
                    HStack(spacing: 12) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.Dark.Signal.caution)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(pr.name)
                                .font(.system(size: 13.5, weight: .semibold))
                                .tracking(-0.1)
                                .foregroundStyle(AppTheme.Dark.text)
                            Text(pr.detail)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(AppTheme.Dark.text3)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(pr.delta)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.Dark.Signal.recovery)
                            Text(pr.when)
                                .font(.system(size: 8.5, design: .monospaced))
                                .tracking(0.6)
                                .foregroundStyle(AppTheme.Dark.text4)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .overlay(alignment: .bottom) {
                        if index < data.recentPRs.count - 1 {
                            Rectangle().fill(AppTheme.Dark.hairlineSoft).frame(height: 0.5).padding(.leading, 14)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .darkCard(radius: 16)
        }
    }

    // MARK: - Insights link

    private var insightsLink: some View {
        NavigationLink {
            InsightsView()
        } label: {
            HStack {
                Text("Patterns, muscles & more")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.Dark.text2)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.Dark.text4)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 14)
            .darkCard(radius: 14)
        }
        .buttonStyle(.pressableCard)
        .padding(.horizontal, 18)
        .padding(.top, 22)
    }

    // MARK: - Section scaffold

    @ViewBuilder
    private func section<Content: View>(
        title: String,
        right: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(AppTheme.Dark.text3)
                Spacer()
                if let right {
                    Text(right)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(0.6)
                        .foregroundStyle(AppTheme.Dark.text4)
                }
            }
            content()
        }
        .padding(.horizontal, 18)
        .padding(.top, 26)
    }
}

/// Trends-only palette bits that aren't general tokens.
enum TrendsPalette {
    /// Past-week volume bars — a muted teal so the current week's accent leads.
    /// (design_handoff_app: oklch(0.45 0.06 190) ≈ #2E7C74)
    static let pastWeek = Color(red: 0.180, green: 0.486, blue: 0.455)
}

/// A trim-animated trajectory line with a gradient area fill under it — the HRV
/// story, drawn in over 1.6s.
private struct TrajectoryLine: View {
    let values: [Double]
    let accent: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let points = normalizedPoints(in: geo.size)
            ZStack {
                areaPath(points, height: geo.size.height)
                    .fill(LinearGradient(
                        colors: [accent.opacity(0.32), accent.opacity(0)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .opacity(drawn > 0 ? 1 : 0)
                linePath(points)
                    .trim(from: 0, to: drawn)
                    .stroke(accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .signalGlow(accent, radius: 3, opacity: 0.5)
                if let last = points.last, drawn >= 1 {
                    Circle()
                        .fill(AppTheme.Dark.text)
                        .frame(width: 7, height: 7)
                        .overlay(Circle().strokeBorder(accent, lineWidth: 2))
                        .position(last)
                }
            }
        }
        .onAppear {
            guard !reduceMotion else { drawn = 1; return }
            withAnimation(.easeInOut(duration: 1.6)) { drawn = 1 }
        }
        .accessibilityElement()
        .accessibilityLabel("HRV trajectory over \(values.count) days")
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let lo = values.min() ?? 0
        let hi = values.max() ?? 1
        let span = max(0.0001, hi - lo)
        return values.enumerated().map { index, value in
            let x = CGFloat(index) / CGFloat(values.count - 1) * size.width
            let y = size.height - 4 - CGFloat((value - lo) / span) * (size.height - 8)
            return CGPoint(x: x, y: y)
        }
    }

    private func linePath(_ points: [CGPoint]) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            points.dropFirst().forEach { path.addLine(to: $0) }
        }
    }

    private func areaPath(_ points: [CGPoint], height: CGFloat) -> Path {
        Path { path in
            guard let first = points.first, let last = points.last else { return }
            path.move(to: CGPoint(x: first.x, y: height))
            path.addLine(to: first)
            points.dropFirst().forEach { path.addLine(to: $0) }
            path.addLine(to: CGPoint(x: last.x, y: height))
            path.closeSubpath()
        }
    }
}

#Preview("Empty") {
    NavigationStack {
        ScrollView { EmptyTrendsContent() }
            .background(AppTheme.Dark.bg)
    }
    .preferredColorScheme(.dark)
}
