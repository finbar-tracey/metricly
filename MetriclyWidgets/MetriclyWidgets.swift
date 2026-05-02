import WidgetKit
import SwiftUI

// MARK: - Shared data

struct WidgetSnapshot: Codable {
    var streakDays: Int            = 0
    var todayWorkoutName: String   = ""
    var weeklyCardioKm: Double     = 0
    var lastRunPace: String        = ""
    var lastRunDist: String        = ""
    var weeklyGoal: Int            = 0
    var workoutsThisWeek: Int      = 0
    var weeklyCardioGoalKm: Double = 0
    var todayScheduledName: String = ""
}

let appGroupSuite = "group.com.Finbar.FinApp"

func loadSnapshot() -> WidgetSnapshot {
    guard let defaults = UserDefaults(suiteName: appGroupSuite),
          let data = defaults.data(forKey: "widgetData"),
          let snap = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    else { return WidgetSnapshot() }
    return snap
}

// MARK: - Entry & Provider

struct MetriclyEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct MetriclyProvider: TimelineProvider {
    func placeholder(in context: Context) -> MetriclyEntry {
        MetriclyEntry(date: .now, snapshot: WidgetSnapshot(
            streakDays: 12, todayWorkoutName: "Leg Day",
            weeklyCardioKm: 14.2, weeklyGoal: 4, workoutsThisWeek: 3
        ))
    }
    func getSnapshot(in context: Context, completion: @escaping (MetriclyEntry) -> Void) {
        completion(MetriclyEntry(date: .now, snapshot: loadSnapshot()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<MetriclyEntry>) -> Void) {
        let entry = MetriclyEntry(date: .now, snapshot: loadSnapshot())
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Small Widget View

struct StreakWidgetView: View {
    let entry: MetriclyEntry
    private var snap: WidgetSnapshot { entry.snapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Flame icon
            ZStack {
                Circle()
                    .fill(.white.opacity(0.18))
                    .frame(width: 34, height: 34)
                Image(systemName: "flame.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }

            Spacer()

            // Big streak number
            Text("\(snap.streakDays)")
                .font(.system(size: 48, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()

            Text("day streak")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))

            if !snap.todayWorkoutName.isEmpty {
                Spacer().frame(height: 10)
                HStack(spacing: 4) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.60))
                    Text(snap.todayWorkoutName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.70))
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(15)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(red: 1.0, green: 0.52, blue: 0.15),
                         Color(red: 0.88, green: 0.22, blue: 0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Medium Widget View

struct MetriclyWidgetView: View {
    let entry: MetriclyEntry
    private var snap: WidgetSnapshot { entry.snapshot }

    private var weekProgress: Double {
        snap.weeklyGoal > 0 ? min(1.0, Double(snap.workoutsThisWeek) / Double(snap.weeklyGoal)) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack(alignment: .center) {
                Text("Metricly")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.orange)
                    Text("\(snap.streakDays) day streak")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.orange.opacity(0.12), in: Capsule())
            }

            // Today's workout — the big hero line
            VStack(alignment: .leading, spacing: 2) {
                Text("TODAY")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .kerning(0.8)
                Text(snap.todayWorkoutName.isEmpty ? "Rest Day" : snap.todayWorkoutName)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(snap.todayWorkoutName.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer()

            // Bottom row — weekly dots + cardio
            HStack(alignment: .bottom, spacing: 0) {
                // Week dots
                VStack(alignment: .leading, spacing: 4) {
                    Text(snap.weeklyGoal > 0
                         ? "\(snap.workoutsThisWeek)/\(snap.weeklyGoal) this week"
                         : "\(snap.workoutsThisWeek) this week")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 5) {
                        ForEach(0..<max(snap.weeklyGoal, 5), id: \.self) { i in
                            Circle()
                                .fill(i < snap.workoutsThisWeek ? Color.accentColor : Color.accentColor.opacity(0.15))
                                .frame(width: 8, height: 8)
                        }
                    }
                }

                Spacer()

                // Cardio stat
                if snap.weeklyCardioKm > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.1f km", snap.weeklyCardioKm))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                            .monospacedDigit()
                        HStack(spacing: 3) {
                            Image(systemName: "figure.run")
                                .font(.system(size: 9, weight: .semibold))
                            Text("this week")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .containerBackground(for: .widget) {
            Color(.secondarySystemGroupedBackground)
        }
    }
}

// MARK: - Large Widget View

struct MetriclyLargeWidgetView: View {
    let entry: MetriclyEntry
    private var snap: WidgetSnapshot { entry.snapshot }

    private var weekProgress: Double {
        snap.weeklyGoal > 0 ? min(1.0, Double(snap.workoutsThisWeek) / Double(snap.weeklyGoal)) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Gradient header panel
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [Color(red: 1.0, green: 0.52, blue: 0.15),
                             Color(red: 0.88, green: 0.22, blue: 0.10)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle().fill(.white.opacity(0.07)).frame(width: 120).offset(x: 200, y: -20)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Metricly")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.75))
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white.opacity(0.90))
                        Text("\(snap.streakDays)")
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                    }
                    Text("day streak")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                }
                .padding(18)
            }
            .frame(height: 140)

            // Content area
            VStack(alignment: .leading, spacing: 14) {
                // Today
                VStack(alignment: .leading, spacing: 3) {
                    Text("TODAY")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .kerning(0.8)
                    Text(snap.todayWorkoutName.isEmpty ? "Rest Day" : snap.todayWorkoutName)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(snap.todayWorkoutName.isEmpty ? .secondary : .primary)
                }

                Divider()

                // Weekly progress
                if snap.weeklyGoal > 0 {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Weekly Goal")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(snap.workoutsThisWeek) of \(snap.weeklyGoal) workouts")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.12))
                                    .frame(height: 8)
                                Capsule()
                                    .fill(LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                                                         startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width * weekProgress, height: 8)
                            }
                        }
                        .frame(height: 8)
                    }
                }

                // Cardio
                if snap.weeklyCardioKm > 0 {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange.opacity(0.12))
                                .frame(width: 34, height: 34)
                            Image(systemName: "figure.run")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.orange)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(String(format: "%.1f km", snap.weeklyCardioKm))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                            Text("cardio this week")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if !snap.lastRunDist.isEmpty {
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(snap.lastRunDist)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.primary)
                                Text("last run")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(16)

            Spacer()
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

// MARK: - Widget definitions

struct StreakWidget: Widget {
    let kind = "StreakWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MetriclyProvider()) { entry in
            StreakWidgetView(entry: entry)
        }
        .configurationDisplayName("Streak")
        .description("Your current workout streak.")
        .supportedFamilies([.systemSmall])
    }
}

struct MetriclyWidget: Widget {
    let kind = "MetriclyWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MetriclyProvider()) { entry in
            MetriclyWidgetView(entry: entry)
        }
        .configurationDisplayName("Metricly Dashboard")
        .description("Streak, weekly goal and cardio at a glance.")
        .supportedFamilies([.systemMedium])
    }
}

struct MetriclyLargeWidget: Widget {
    let kind = "MetriclyLargeWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MetriclyProvider()) { entry in
            MetriclyLargeWidgetView(entry: entry)
        }
        .configurationDisplayName("Metricly Full")
        .description("Streak, today's workout, weekly goal and cardio.")
        .supportedFamilies([.systemLarge])
    }
}
