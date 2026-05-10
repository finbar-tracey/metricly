import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct MetriclyEntry: TimelineEntry {
    let date:         Date
    let streak:       Int
    let todayPlan:    String
    /// When non-nil, the Watch has an active workout going. Complications
    /// render an "In Progress" state so a glance shows the current session
    /// instead of yesterday's streak.
    let activeStartedAt: Date?
    let activeName:      String
}

// MARK: - Timeline Provider

struct MetriclyProvider: TimelineProvider {

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: "group.com.Finbar.FinApp")
    }

    func placeholder(in context: Context) -> MetriclyEntry {
        MetriclyEntry(date: .now,
                      streak: 7,
                      todayPlan: "Push Day",
                      activeStartedAt: nil,
                      activeName: "")
    }

    func getSnapshot(in context: Context, completion: @escaping (MetriclyEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MetriclyEntry>) -> Void) {
        // If there's an active workout, refresh every minute so the elapsed
        // timer in the complication actually ticks. Otherwise the static
        // streak/plan changes infrequently and an hourly cadence is fine.
        let entry = entry()
        let next: Date
        if entry.activeStartedAt != nil {
            next = Calendar.current.date(byAdding: .minute, value: 1, to: .now) ?? .now
        } else {
            next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        }
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func entry() -> MetriclyEntry {
        let streak    = defaults?.integer(forKey: "watch.currentStreak") ?? 0
        let todayPlan = defaults?.string(forKey: "watch.todayPlanName")  ?? ""
        let startedTS = defaults?.double(forKey: "watch.activeStartedAt") ?? 0
        let startedAt: Date? = startedTS > 0 ? Date(timeIntervalSince1970: startedTS) : nil
        let activeName = defaults?.string(forKey: "watch.activeName") ?? ""
        return MetriclyEntry(date: .now,
                             streak: streak,
                             todayPlan: todayPlan,
                             activeStartedAt: startedAt,
                             activeName: activeName)
    }
}

// MARK: - Complication Views

// MARK: - Helpers

private func elapsedShort(from start: Date) -> String {
    let secs = max(0, Int(Date.now.timeIntervalSince(start)))
    let h = secs / 3600
    let m = (secs % 3600) / 60
    return h > 0 ? "\(h)h \(m)m" : "\(m)m"
}

// .accessoryCircular — streak flame ring (or workout-in-progress dot)
struct CircularView: View {
    let entry: MetriclyEntry
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let startedAt = entry.activeStartedAt {
                VStack(spacing: 0) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.green)
                    Text(elapsedShort(from: startedAt))
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
            } else {
                VStack(spacing: 1) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.orange)
                    Text("\(entry.streak)")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .minimumScaleFactor(0.7)
                }
            }
        }
    }
}

// .accessoryRectangular — workout state or streak + today's plan
struct RectangularView: View {
    let entry: MetriclyEntry
    var body: some View {
        if let startedAt = entry.activeStartedAt {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .foregroundStyle(.green)
                    Text("In Progress")
                        .font(.headline)
                }
                HStack(spacing: 6) {
                    if !entry.activeName.isEmpty {
                        Text(entry.activeName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Text(elapsedShort(from: startedAt))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").foregroundStyle(.orange)
                    Text(entry.streak == 1 ? "1 day streak" : "\(entry.streak) day streak")
                        .font(.headline)
                }
                if entry.todayPlan.isEmpty {
                    Text("No plan today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(entry.todayPlan)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

// .accessoryInline — compact single-line
struct InlineView: View {
    let entry: MetriclyEntry
    var body: some View {
        if let startedAt = entry.activeStartedAt {
            Label("\(entry.activeName.isEmpty ? "Workout" : entry.activeName) · \(elapsedShort(from: startedAt))",
                  systemImage: "figure.strengthtraining.traditional")
        } else if entry.todayPlan.isEmpty {
            Label("\(entry.streak) day streak", systemImage: "flame.fill")
        } else {
            Label(entry.todayPlan, systemImage: "dumbbell.fill")
        }
    }
}

// .accessoryCorner — small corner badge
struct CornerView: View {
    let entry: MetriclyEntry
    var body: some View {
        if let startedAt = entry.activeStartedAt {
            Image(systemName: "figure.strengthtraining.traditional")
                .foregroundStyle(.green)
                .widgetLabel(elapsedShort(from: startedAt))
        } else {
            Image(systemName: "flame.fill")
                .foregroundStyle(.orange)
                .widgetLabel("\(entry.streak)")
        }
    }
}

// MARK: - Widget Configuration

struct MetriclyWatchWidget: Widget {
    let kind = "MetriclyWatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MetriclyProvider()) { entry in
            MetriclyWidgetEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Metricly")
        .description("Streak and today's workout plan.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

struct MetriclyWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: MetriclyEntry

    var body: some View {
        switch family {
        case .accessoryCircular:    CircularView(entry: entry)
        case .accessoryRectangular: RectangularView(entry: entry)
        case .accessoryCorner:      CornerView(entry: entry)
        default:                    InlineView(entry: entry)
        }
    }
}

// MARK: - Bundle

@main
struct MetriclyWatchComplicationsBundle: WidgetBundle {
    var body: some Widget {
        MetriclyWatchWidget()
    }
}
