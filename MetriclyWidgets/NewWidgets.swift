import WidgetKit
import SwiftUI
import AppIntents

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Shared data helpers (mirrors WidgetDataWriter structs)
// ─────────────────────────────────────────────────────────────────────────────

private let suite = "group.com.finbartracey.tracker"

private func loadCaffeineData() -> CaffeineWidgetData {
    guard let defaults = UserDefaults(suiteName: suite),
          let raw  = defaults.data(forKey: "caffeineWidgetData"),
          let data = try? JSONDecoder().decode(CaffeineWidgetData.self, from: raw)
    else { return CaffeineWidgetData() }
    return data
}

private func loadWaterData() -> WaterWidgetData {
    guard let defaults = UserDefaults(suiteName: suite),
          let raw  = defaults.data(forKey: "waterWidgetData"),
          let data = try? JSONDecoder().decode(WaterWidgetData.self, from: raw)
    else { return WaterWidgetData() }
    return data
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Caffeine data model
// ─────────────────────────────────────────────────────────────────────────────

struct CaffeineWidgetData: Codable {
    struct Entry: Codable { var date: Date; var milligrams: Double }
    var entries: [Entry]         = []
    var halfLifeHours: Double    = 5.0
    var dailyLimitMg: Double     = 400

    func remainingMg(at time: Date = .now) -> Double {
        entries.reduce(0.0) { sum, e in
            let elapsed = max(0, time.timeIntervalSince(e.date))
            return sum + e.milligrams * pow(0.5, elapsed / (halfLifeHours * 3600))
        }
    }

    var clearDate: Date? {
        let total = remainingMg()
        guard total > 10 else { return nil }
        let t = halfLifeHours * 3600 * log2(total / 10)
        return Date().addingTimeInterval(t)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Water data model
// ─────────────────────────────────────────────────────────────────────────────

struct WaterWidgetData: Codable {
    var todayMl: Double = 0
    var goalMl: Double  = 2500

    var progress: Double { goalMl > 0 ? min(1, todayMl / goalMl) : 0 }
    var isComplete: Bool { todayMl >= goalMl }

    var formattedToday: String {
        todayMl >= 1000 ? String(format: "%.1fL", todayMl / 1000) : String(format: "%.0f ml", todayMl)
    }
    var formattedGoal: String {
        goalMl >= 1000 ? String(format: "%.1fL", goalMl / 1000) : String(format: "%.0f ml", goalMl)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - 1. CAFFEINE HALF-LIFE WIDGET
// ─────────────────────────────────────────────────────────────────────────────

struct CaffeineTimelineEntry: TimelineEntry {
    let date: Date
    let remainingMg: Double
    let data: CaffeineWidgetData
}

struct CaffeineProvider: TimelineProvider {
    func placeholder(in context: Context) -> CaffeineTimelineEntry {
        CaffeineTimelineEntry(date: .now, remainingMg: 180, data: CaffeineWidgetData(
            entries: [.init(date: Date().addingTimeInterval(-3600), milligrams: 200)],
            halfLifeHours: 5, dailyLimitMg: 400
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (CaffeineTimelineEntry) -> Void) {
        let data = loadCaffeineData()
        completion(CaffeineTimelineEntry(date: .now, remainingMg: data.remainingMg(), data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CaffeineTimelineEntry>) -> Void) {
        let data = loadCaffeineData()
        var entries: [CaffeineTimelineEntry] = []

        // Snapshot every 15 min for the next 8 h so the arc decays smoothly
        for i in 0..<(8 * 4) {
            let t = Date().addingTimeInterval(Double(i) * 15 * 60)
            let mg = data.remainingMg(at: t)
            entries.append(CaffeineTimelineEntry(date: t, remainingMg: mg, data: data))
            if mg < 5 { break }     // nothing left to show, stop early
        }

        let refresh = Calendar.current.date(byAdding: .hour, value: 8, to: .now) ?? .now
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }
}

struct CaffeineWidgetView: View {
    let entry: CaffeineTimelineEntry

    private var mg: Double { max(0, entry.remainingMg) }
    private var limit: Double { max(1, entry.data.dailyLimitMg) }
    private var progress: Double { min(1, mg / limit) }

    private var arcColor: Color {
        switch progress {
        case 0.6...: return Color(red: 0.55, green: 0.27, blue: 0.07)   // dark espresso
        case 0.3..<0.6: return Color(red: 0.75, green: 0.45, blue: 0.1) // amber
        default:         return Color(red: 0.3,  green: 0.6,  blue: 0.3) // green = clear
        }
    }

    private var timeLabel: String {
        guard mg > 10 else { return "Cleared ✓" }
        guard let clear = entry.data.clearDate else { return "Cleared ✓" }
        let interval = clear.timeIntervalSince(entry.date)
        guard interval > 0 else { return "Cleared ✓" }
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        if h > 0 { return "Clear in \(h)h \(m)m" }
        return "Clear in \(m)m"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Arc ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 9, lineCap: .round))
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [arcColor, arcColor.opacity(0.6)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.4), value: progress)

                VStack(spacing: 1) {
                    if mg < 5 {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.green)
                    } else {
                        Text(mg >= 100 ? String(format: "%.0f", mg) : String(format: "%.0f", mg))
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                        Text("mg")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .frame(width: 72, height: 72)

            Spacer().frame(height: 6)

            Text(timeLabel)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(mg < 5 ? 0.9 : 0.65))
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(red: 0.18, green: 0.10, blue: 0.05),
                         Color(red: 0.10, green: 0.06, blue: 0.02)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
        .overlay(alignment: .topLeading) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.45))
                .padding(10)
        }
    }
}

struct CaffeineWidget: Widget {
    let kind = "CaffeineWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CaffeineProvider()) { entry in
            CaffeineWidgetView(entry: entry)
        }
        .configurationDisplayName("Caffeine")
        .description("Real-time caffeine half-life countdown.")
        .supportedFamilies([.systemSmall])
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - 2. WATER RING WIDGET
// ─────────────────────────────────────────────────────────────────────────────

struct WaterEntry2: TimelineEntry {   // named to avoid clash with SwiftData model
    let date: Date
    let data: WaterWidgetData
}

struct WaterProvider: TimelineProvider {
    func placeholder(in context: Context) -> WaterEntry2 {
        WaterEntry2(date: .now, data: WaterWidgetData(todayMl: 1750, goalMl: 2500))
    }
    func getSnapshot(in context: Context, completion: @escaping (WaterEntry2) -> Void) {
        completion(WaterEntry2(date: .now, data: loadWaterData()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WaterEntry2>) -> Void) {
        let entry = WaterEntry2(date: .now, data: loadWaterData())
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct WaterRingWidgetView: View {
    let entry: WaterEntry2
    private var data: WaterWidgetData { entry.data }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Track
                Circle()
                    .stroke(Color.white.opacity(0.12),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round))
                // Fill
                Circle()
                    .trim(from: 0, to: data.progress)
                    .stroke(
                        LinearGradient(
                            colors: [Color(red: 0.25, green: 0.65, blue: 1.0),
                                     Color(red: 0.10, green: 0.45, blue: 0.9)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.4), value: data.progress)

                VStack(spacing: 1) {
                    if data.isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Text(data.formattedToday)
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                    }
                }
            }
            .frame(width: 76, height: 76)

            Spacer().frame(height: 6)

            Text(data.isComplete ? "Goal met! 💧" : "of \(data.formattedGoal)")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.70))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.28, blue: 0.60),
                         Color(red: 0.04, green: 0.18, blue: 0.42)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
        .overlay(alignment: .topLeading) {
            Image(systemName: "drop.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.45))
                .padding(10)
        }
        .overlay(alignment: .bottomTrailing) {
            Button(intent: LogWaterFromWidgetIntent()) {
                Label("+250", systemImage: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .labelStyle(.titleOnly)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.20), in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(8)
        }
    }
}

struct WaterWidget: Widget {
    let kind = "WaterWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WaterProvider()) { entry in
            WaterRingWidgetView(entry: entry)
        }
        .configurationDisplayName("Water")
        .description("Today's hydration progress toward your goal.")
        .supportedFamilies([.systemSmall])
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - 3. TODAY'S PLAN WIDGET
// ─────────────────────────────────────────────────────────────────────────────

struct TodaysPlanEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct TodaysPlanProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodaysPlanEntry {
        TodaysPlanEntry(date: .now, snapshot: WidgetSnapshot(todayWorkoutName: "Leg Day", workoutsThisWeek: 2))
    }
    func getSnapshot(in context: Context, completion: @escaping (TodaysPlanEntry) -> Void) {
        completion(TodaysPlanEntry(date: .now, snapshot: loadSnapshot()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodaysPlanEntry>) -> Void) {
        let entry = TodaysPlanEntry(date: .now, snapshot: loadSnapshot())
        // Refresh at midnight so the scheduled name rolls over to the next day
        let midnight = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: .now)!)
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }
}

struct TodaysPlanWidgetView: View {
    let entry: TodaysPlanEntry
    private var snap: WidgetSnapshot { entry.snapshot }

    // Prefer scheduled name, fall back to logged workout, fall back to rest
    private var workoutName: String {
        if !snap.todayScheduledName.isEmpty { return snap.todayScheduledName }
        if !snap.todayWorkoutName.isEmpty   { return snap.todayWorkoutName }
        return "Rest Day"
    }

    private var isRestDay: Bool { workoutName == "Rest Day" }

    private var gradientColors: [Color] {
        if isRestDay {
            return [Color(red: 0.28, green: 0.18, blue: 0.45),
                    Color(red: 0.18, green: 0.10, blue: 0.32)]
        }
        return [Color(red: 1.0,  green: 0.52, blue: 0.15),
                Color(red: 0.88, green: 0.22, blue: 0.10)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Day label
            Text(Date().formatted(.dateTime.weekday(.wide)))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.65))
                .textCase(.uppercase)

            Spacer()

            // Icon
            Image(systemName: isRestDay ? "moon.zzz.fill" : "dumbbell.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))

            Spacer().frame(height: 6)

            // Workout name — big
            Text(workoutName)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.6)

            Spacer()

            // Streak pill
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.70))
                Text("\(snap.streakDays) day streak")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.70))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(14)
        .containerBackground(for: .widget) {
            LinearGradient(colors: gradientColors,
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
        }
    }
}

struct TodaysPlanWidget: Widget {
    let kind = "TodaysPlanWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodaysPlanProvider()) { entry in
            TodaysPlanWidgetView(entry: entry)
        }
        .configurationDisplayName("Today's Plan")
        .description("What's on the schedule for today.")
        .supportedFamilies([.systemSmall])
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - 4. WEEKLY RINGS WIDGET
// ─────────────────────────────────────────────────────────────────────────────

struct WeeklyRingsEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    let water: WaterWidgetData
}

struct WeeklyRingsProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeeklyRingsEntry {
        WeeklyRingsEntry(date: .now,
                         snapshot: WidgetSnapshot(weeklyCardioKm: 8, weeklyGoal: 4,
                                                   workoutsThisWeek: 3, weeklyCardioGoalKm: 20),
                         water: WaterWidgetData(todayMl: 1800, goalMl: 2500))
    }
    func getSnapshot(in context: Context, completion: @escaping (WeeklyRingsEntry) -> Void) {
        completion(WeeklyRingsEntry(date: .now, snapshot: loadSnapshot(), water: loadWaterData()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WeeklyRingsEntry>) -> Void) {
        let entry = WeeklyRingsEntry(date: .now, snapshot: loadSnapshot(), water: loadWaterData())
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct ActivityRingView: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)
        }
    }
}

struct WeeklyRingsWidgetView: View {
    let entry: WeeklyRingsEntry
    private var snap: WidgetSnapshot { entry.snapshot }
    private var water: WaterWidgetData { entry.water }

    private var workoutProgress: Double {
        snap.weeklyGoal > 0 ? min(1, Double(snap.workoutsThisWeek) / Double(snap.weeklyGoal)) : 0
    }
    private var cardioProgress: Double {
        snap.weeklyCardioGoalKm > 0 ? min(1, snap.weeklyCardioKm / snap.weeklyCardioGoalKm) : 0
    }
    private var waterProgress: Double { water.progress }

    var body: some View {
        HStack(spacing: 18) {

            // ── Concentric rings ─────────────────────────────────────────────
            ZStack {
                ActivityRingView(progress: workoutProgress, color: .orange,       lineWidth: 10)
                    .frame(width: 100, height: 100)
                ActivityRingView(progress: cardioProgress,  color: .cyan,         lineWidth: 10)
                    .frame(width:  76, height:  76)
                ActivityRingView(progress: waterProgress,   color: Color(red: 0.25, green: 0.65, blue: 1), lineWidth: 10)
                    .frame(width:  52, height:  52)
            }

            // ── Legend ───────────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 10) {
                ringLegendRow(color: .orange, label: "Move",
                              value: snap.weeklyGoal > 0
                                ? "\(snap.workoutsThisWeek)/\(snap.weeklyGoal)"
                                : "\(snap.workoutsThisWeek)",
                              unit: "workouts")

                ringLegendRow(color: .cyan, label: "Cardio",
                              value: snap.weeklyCardioGoalKm > 0
                                ? String(format: "%.0f/%.0f", snap.weeklyCardioKm, snap.weeklyCardioGoalKm)
                                : String(format: "%.1f", snap.weeklyCardioKm),
                              unit: "km")

                ringLegendRow(color: Color(red: 0.25, green: 0.65, blue: 1),
                              label: "Water",
                              value: water.formattedToday,
                              unit: "today")
            }
        }
        .padding(16)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
        .overlay(alignment: .topTrailing) {
            Text("This Week")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(14)
        }
    }

    private func ringLegendRow(color: Color, label: String, value: String, unit: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                Text(unit)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct WeeklyRingsWidget: Widget {
    let kind = "WeeklyRingsWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeeklyRingsProvider()) { entry in
            WeeklyRingsWidgetView(entry: entry)
        }
        .configurationDisplayName("Weekly Rings")
        .description("Workouts, cardio and hydration progress for the week.")
        .supportedFamilies([.systemMedium])
    }
}
