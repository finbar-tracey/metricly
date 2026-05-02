import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct MetriclyEntry: TimelineEntry {
    let date:         Date
    let streak:       Int
    let todayPlan:    String
}

// MARK: - Timeline Provider

struct MetriclyProvider: TimelineProvider {

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: "group.com.Finbar.FinApp")
    }

    func placeholder(in context: Context) -> MetriclyEntry {
        MetriclyEntry(date: .now, streak: 7, todayPlan: "Push Day")
    }

    func getSnapshot(in context: Context, completion: @escaping (MetriclyEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MetriclyEntry>) -> Void) {
        // Refresh once per hour — data changes infrequently
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry()], policy: .after(next)))
    }

    private func entry() -> MetriclyEntry {
        let streak    = defaults?.integer(forKey: "watch.currentStreak") ?? 0
        let todayPlan = defaults?.string(forKey: "watch.todayPlanName")  ?? ""
        return MetriclyEntry(date: .now, streak: streak, todayPlan: todayPlan)
    }
}

// MARK: - Complication Views

// .accessoryCircular — streak flame ring
struct CircularView: View {
    let entry: MetriclyEntry
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
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

// .accessoryRectangular — streak + today's plan
struct RectangularView: View {
    let entry: MetriclyEntry
    var body: some View {
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

// .accessoryInline — compact single-line
struct InlineView: View {
    let entry: MetriclyEntry
    var body: some View {
        if entry.todayPlan.isEmpty {
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
        Image(systemName: "flame.fill")
            .foregroundStyle(.orange)
            .widgetLabel("\(entry.streak)")
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
