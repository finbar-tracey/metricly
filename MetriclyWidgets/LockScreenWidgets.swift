import WidgetKit
import SwiftUI

// MARK: - Lock Screen & StandBy Widget Views
// Uses the same MetriclyEntry / MetriclyProvider / WidgetSnapshot already defined
// in MetriclyWidgets.swift — no duplicate provider needed.

// MARK: - accessoryCircular: streak flame ring

struct LockScreenCircularStreakView: View {
    let snap: WidgetSnapshot

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.orange)
                Text("\(snap.streakDays)")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - accessoryCircular: weekly progress gauge

struct LockScreenCircularWeeklyView: View {
    let snap: WidgetSnapshot

    private var progress: Double {
        guard snap.weeklyGoal > 0 else { return 0 }
        return min(1.0, Double(snap.workoutsThisWeek) / Double(snap.weeklyGoal))
    }

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(.secondary.opacity(0.3), lineWidth: 5)

            // Progress arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [.blue, .cyan],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text("\(snap.workoutsThisWeek)")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .monospacedDigit()
                Text("/ \(snap.weeklyGoal)")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - accessoryRectangular: streak + plan + week count

struct LockScreenRectangularView: View {
    let snap: WidgetSnapshot

    private var planText: String {
        if !snap.todayScheduledName.isEmpty { return snap.todayScheduledName }
        if !snap.todayWorkoutName.isEmpty   { return snap.todayWorkoutName }
        return "No plan today"
    }

    var body: some View {
        HStack(spacing: 10) {
            // Left: streak
            VStack(spacing: 2) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.orange)
                Text("\(snap.streakDays)")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .monospacedDigit()
                Text("day\(snap.streakDays == 1 ? "" : "s")")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 44)

            Divider()

            // Right: plan + weekly count
            VStack(alignment: .leading, spacing: 3) {
                Text(planText)
                    .font(.subheadline.bold())
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                    Text("\(snap.workoutsThisWeek) / \(snap.weeklyGoal) this week")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - accessoryInline: single-line summary

struct LockScreenInlineView: View {
    let snap: WidgetSnapshot

    private var planLabel: String {
        let plan = snap.todayScheduledName.isEmpty ? snap.todayWorkoutName : snap.todayScheduledName
        return plan.isEmpty ? "Rest day" : plan
    }

    var body: some View {
        // WidgetKit renders this as text only; Label is best for inline
        Label("\(snap.streakDays) days · \(planLabel)", systemImage: "flame.fill")
    }
}

// MARK: - Widget Definitions

/// Single widget covering all lock-screen families
struct MetriclyLockScreenWidget: Widget {
    let kind = "MetriclyLockScreen"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MetriclyProvider()) { entry in
            MetriclyLockScreenEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Metricly")
        .description("Streak, weekly progress and today's plan on your lock screen.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

struct MetriclyLockScreenEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: MetriclyEntry

    private var snap: WidgetSnapshot { entry.snapshot }

    var body: some View {
        switch family {
        case .accessoryCircular:
            // Alternate between streak and weekly ring based on whether a goal is set
            if snap.weeklyGoal > 0 {
                LockScreenCircularWeeklyView(snap: snap)
            } else {
                LockScreenCircularStreakView(snap: snap)
            }
        case .accessoryRectangular:
            LockScreenRectangularView(snap: snap)
        default:
            LockScreenInlineView(snap: snap)
        }
    }
}

// MARK: - Standalone streak circular (always shows streak, not weekly ring)

struct MetriclyStreakCircularWidget: Widget {
    let kind = "MetriclyStreakCircular"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MetriclyProvider()) { entry in
            LockScreenCircularStreakView(snap: entry.snapshot)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Streak")
        .description("Your current workout streak.")
        .supportedFamilies([.accessoryCircular])
    }
}
