import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct MetriclyEntry: TimelineEntry {
    let date:         Date
    let streak:       Int
    /// The schedule's literal label for today (e.g. "Push Day"). Used as
    /// the fallback when the engine hasn't computed an adaptive plan yet.
    let todayPlan:    String
    /// The engine's recommendation for today (e.g. "Recovery" when the
    /// schedule says "Push" but recovery is low). Preferred over
    /// `todayPlan` whenever non-empty — that's the whole point of the
    /// adaptive coach feature: the complication should show what the
    /// user *should* train, not what the calendar says.
    let adaptivePlan:    String
    /// `TodayPlan.Intensity.rawValue` for the recommendation
    /// ("rest"/"light"/"moderate"/"hard"). Powers an inline badge in
    /// rectangular and a "Plan · Intensity" pattern in inline.
    let adaptiveIntensity: String
    /// When non-nil, the Watch has an active workout going. Complications
    /// render an "In Progress" state so a glance shows the current session
    /// instead of yesterday's streak.
    let activeStartedAt: Date?
    let activeName:      String
}

// MARK: - Timeline Provider

struct MetriclyProvider: TimelineProvider {

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: WidgetAppGroup.suiteName)
    }

    func placeholder(in context: Context) -> MetriclyEntry {
        MetriclyEntry(date: .now,
                      streak: 7,
                      todayPlan: "Push Day",
                      adaptivePlan: "Push Day",
                      adaptiveIntensity: "moderate",
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
        // Adaptive plan keys — written by PhoneConnectivityManager when
        // the engine recomputes the recommendation. Empty string means
        // the phone hasn't published an adaptive plan yet (first launch
        // before any HomeDashboardView render), so we fall back to the
        // schedule's literal label below.
        let adaptivePlan      = defaults?.string(forKey: "watch.adaptivePlanName")  ?? ""
        let adaptiveIntensity = defaults?.string(forKey: "watch.adaptiveIntensity") ?? ""
        let startedTS = defaults?.double(forKey: "watch.activeStartedAt") ?? 0
        let startedAt: Date? = startedTS > 0 ? Date(timeIntervalSince1970: startedTS) : nil
        let activeName = defaults?.string(forKey: "watch.activeName") ?? ""
        return MetriclyEntry(date: .now,
                             streak: streak,
                             todayPlan: todayPlan,
                             adaptivePlan: adaptivePlan,
                             adaptiveIntensity: adaptiveIntensity,
                             activeStartedAt: startedAt,
                             activeName: activeName)
    }
}

// MARK: - Plan display helpers

/// The label the complication should actually show — engine's adaptive
/// recommendation wins over the schedule's literal label, with empty
/// string as the final fallback ("No plan today" upstream).
private func displayPlan(_ entry: MetriclyEntry) -> String {
    entry.adaptivePlan.isEmpty ? entry.todayPlan : entry.adaptivePlan
}

/// Two-letter shorthand for the intensity badge in tight complication
/// real estate. nil means "no badge worth showing" (no intensity or
/// moderate, which is the neutral default users don't need flagged).
private func intensityShort(_ raw: String) -> String? {
    switch raw {
    case "rest":     return "Rest"
    case "light":    return "Light"
    case "hard":     return "Hard"
    case "moderate": return nil       // default, not worth taxing the user's eye with
    default:         return nil
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
                let plan = displayPlan(entry)
                if plan.isEmpty {
                    Text("No plan today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 4) {
                        Text(plan)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        if let badge = intensityShort(entry.adaptiveIntensity) {
                            Text(badge.uppercased())
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.secondary.opacity(0.18),
                                            in: Capsule())
                        }
                    }
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
        } else {
            let plan = displayPlan(entry)
            if plan.isEmpty {
                Label("\(entry.streak) day streak", systemImage: "flame.fill")
            } else if let badge = intensityShort(entry.adaptiveIntensity) {
                // "Push · Hard" form when the engine has flagged today
                // as non-default intensity — surfaces the adaptive
                // recommendation at a single glance.
                Label("\(plan) · \(badge)", systemImage: "dumbbell.fill")
            } else {
                Label(plan, systemImage: "dumbbell.fill")
            }
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
