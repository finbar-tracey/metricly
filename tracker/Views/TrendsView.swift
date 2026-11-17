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
    /// Built once per data change (not per body evaluation).
    @State private var cachedData: TrendsData?
    @ScaledMetric(relativeTo: .caption2) private var chartHeight: CGFloat = 92
    @ScaledMetric(relativeTo: .caption2) private var barMaxHeight: CGFloat = 76

    /// Inputs that change what the dashboard shows.
    private struct RefreshKey: Equatable {
        var workouts: Int
        var latestWorkout: Date?
        var cardio: Int
        var unit: WeightUnit
    }

    private var refreshKey: RefreshKey {
        RefreshKey(workouts: finishedWorkouts.count, latestWorkout: finishedWorkouts.first?.date,
                   cardio: cardioSessions.count, unit: weightUnit)
    }

    private func buildData() -> TrendsData {
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
        let data = cachedData ?? buildData()
        return ScrollView {
            Group {
                if data.isEmpty {
                    EmptyTrendsContent()
                } else {
                    content(data)
                }
            }
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .onChange(of: refreshKey, initial: true) { _, _ in
            cachedData = buildData()
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

    private func content(_ data: TrendsData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            title(data)
            statGrid(data)
            weeklyVolume(data)
            if hrvSeries.count >= 2 {
                hrvTrajectory
            }
            if !data.recentPRs.isEmpty {
                recentPRs(data)
            }
            insightsLink
        }
        .padding(.bottom, 28)
    }

    // MARK: - Title

    private func title(_ data: TrendsData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(data.verdictA)
                    .foregroundStyle(AppTheme.Dark.text)
                Text(data.verdictB)
                    .foregroundStyle(AppTheme.Dark.Signal.recovery)
            }
            .font(.system(.title, design: .rounded).weight(.bold))
            .tracking(-1.2)
            .accessibilityElement(children: .combine)
            Text(data.subline)
                .font(.footnote)
                .foregroundStyle(AppTheme.Dark.text3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 14)
    }

    // MARK: - Stat grid

    private func statGrid(_ data: TrendsData) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 160), spacing: 10)],
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
                .textCase(.uppercase)
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .tracking(1)
                .foregroundStyle(AppTheme.Dark.text4)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                CountUpNumber(target: stat.value, decimals: stat.decimals)
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .tracking(-1)
                    .foregroundStyle(stat.tone)
                    .monospacedDigit()
                Text(stat.unit)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(AppTheme.Dark.text3)
            }
            Text(stat.sub)
                .font(.system(.caption2, design: .monospaced))
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

    private func weeklyVolume(_ data: TrendsData) -> some View {
        section(title: String(localized: "Weekly volume", comment: "Trends section title (shown uppercase)"),
                right: String(localized: "k·\(weightUnit.label) lifted", comment: "Trends weekly volume unit caption; thousands of the user's weight unit")) {
            let maxVolume = max(0.01, data.weeklyVolume.map(\.volumeK).max() ?? 0)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(data.weeklyVolume.enumerated()), id: \.element.id) { index, week in
                    volumeBar(week, maxVolume: maxVolume, index: index)
                }
            }
            .frame(height: chartHeight, alignment: .bottom)
        }
    }

    private func volumeBar(_ week: TrendsData.WeekBar, maxVolume: Double, index: Int) -> some View {
        VStack(spacing: 3) {
            Text(week.volumeK, format: .number.precision(.fractionLength(0)))
                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundStyle(week.isCurrent ? AppTheme.Dark.Signal.recovery : AppTheme.Dark.text4)
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(week.isCurrent
                      ? AnyShapeStyle(LinearGradient(colors: [AppTheme.Dark.Signal.recovery, AppTheme.Dark.Signal.recovery.opacity(0.9)], startPoint: .top, endPoint: .bottom))
                      : AnyShapeStyle(TrendsPalette.pastWeek))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(AppTheme.Dark.text, lineWidth: week.isCurrent ? 1.5 : 0)
                )
                .frame(height: max(4, CGFloat(week.volumeK / maxVolume) * barMaxHeight))
                .signalGlow(week.isCurrent ? AppTheme.Dark.Signal.recovery : .clear, radius: 10)
                .growIn(delay: Double(index) * 0.07)
            Text(week.isCurrent ? String(localized: "Now", comment: "Trends chart label under the current week bar (shown uppercase)") : " ")
                .textCase(.uppercase)
                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                .foregroundStyle(AppTheme.Dark.text2)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(volumeSpokenLabel(week))
    }

    private func volumeSpokenLabel(_ week: TrendsData.WeekBar) -> String {
        let volume = week.volumeK.formatted(.number.precision(.fractionLength(0)))
        let unit = weightUnit == .kg
            ? String(localized: "kilograms", comment: "Spoken weight unit")
            : String(localized: "pounds", comment: "Spoken weight unit")
        if week.isCurrent {
            return String(localized: "This week: \(volume) thousand \(unit)", comment: "VoiceOver: current week's lifted volume")
        }
        let date = week.weekStart.formatted(.dateTime.month(.abbreviated).day())
        return String(localized: "Week of \(date): \(volume) thousand \(unit)", comment: "VoiceOver: a past week's lifted volume; date is the week start")
    }

    // MARK: - HRV trajectory

    private var hrvTrajectory: some View {
        let lo = hrvSeries.min() ?? 0
        let hi = hrvSeries.max() ?? 0
        return section(
            title: String(localized: "HRV trajectory · \(hrvSeries.count) day", comment: "Trends section title (shown uppercase); count of days"),
            right: String(localized: "\(Int(lo)) → \(Int(hi)) ms", comment: "HRV range low to high in milliseconds")
        ) {
            VStack(spacing: 8) {
                TrajectoryLine(values: hrvSeries, accent: AppTheme.Dark.Signal.recovery)
                    .frame(height: 74)
                HStack {
                    Text("\(hrvSeries.count) days ago")
                        .textCase(.uppercase)
                        .font(.system(.caption2, design: .monospaced).weight(.semibold))
                        .foregroundStyle(AppTheme.Dark.text4)
                    Spacer()
                    let delta = (hrvSeries.last ?? 0) - (hrvSeries.first ?? 0)
                    Text(delta >= 0
                         ? String(localized: "+\(Int(delta)) ms · baseline rising", comment: "HRV delta caption when rising (shown uppercase)")
                         : String(localized: "\(Int(delta)) ms · eased off", comment: "HRV delta caption when falling (shown uppercase)"))
                        .textCase(.uppercase)
                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                        .foregroundStyle(delta >= 0 ? AppTheme.Dark.Signal.recovery : AppTheme.Dark.Signal.caution)
                }
            }
            .padding(14)
            .darkCard(radius: 16)
        }
    }

    // MARK: - Recent PRs

    private func recentPRs(_ data: TrendsData) -> some View {
        section(title: String(localized: "Recent PRs", comment: "Trends section title (shown uppercase)"),
                right: String(localized: "\(data.recentPRs.count) recent", comment: "Trends recent PR count caption (shown uppercase)")) {
            VStack(spacing: 0) {
                ForEach(Array(data.recentPRs.enumerated()), id: \.element.id) { index, pr in
                    HStack(spacing: 12) {
                        Image(systemName: "flame.fill")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppTheme.Dark.Signal.caution)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(pr.name)
                                .font(.subheadline.weight(.semibold))
                                .tracking(-0.1)
                                .foregroundStyle(AppTheme.Dark.text)
                            Text(pr.detail)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(AppTheme.Dark.text3)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(pr.delta)
                                .font(.system(.caption, design: .monospaced).weight(.bold))
                                .foregroundStyle(AppTheme.Dark.Signal.recovery)
                            Text(pr.when)
                                .textCase(.uppercase)
                                .font(.system(.caption2, design: .monospaced))
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
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Dark.text2)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
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
                    .textCase(.uppercase)
                    .font(.system(.caption2, design: .monospaced).weight(.semibold))
                    .tracking(1.4)
                    .foregroundStyle(AppTheme.Dark.text3)
                Spacer()
                if let right {
                    Text(right)
                        .textCase(.uppercase)
                        .font(.system(.caption2, design: .monospaced).weight(.semibold))
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
