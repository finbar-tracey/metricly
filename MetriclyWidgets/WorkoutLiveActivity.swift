import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Attributes (mirrors WorkoutActivity.swift in main app — must stay in sync)

struct WorkoutActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var exerciseCount: Int
        var setCount: Int
        var currentExercise: String
        var elapsedSeconds: Int

        var formattedElapsed: String {
            let h = elapsedSeconds / 3600
            let m = (elapsedSeconds % 3600) / 60
            let s = elapsedSeconds % 60
            if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
            return String(format: "%d:%02d", m, s)
        }
    }

    var workoutName: String
    var startDate: Date
}

// MARK: - Lock Screen / Notification View

struct WorkoutLockScreenView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        HStack(spacing: 16) {
            // Flame / active icon
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(red: 1.0, green: 0.52, blue: 0.15),
                                 Color(red: 0.88, green: 0.22, blue: 0.10)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 46, height: 46)
                Image(systemName: "flame.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(context.attributes.workoutName)
                    .font(.headline)
                    .lineLimit(1)
                Text(context.state.currentExercise)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(context.state.formattedElapsed)
                    .font(.system(.title3, design: .monospaced).bold())
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Label("\(context.state.setCount)", systemImage: "repeat")
                    Text("sets")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Dynamic Island Views

struct WorkoutDynamicIslandCompactLeading: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>
    var body: some View {
        Image(systemName: "flame.fill")
            .foregroundStyle(.orange)
            .font(.system(size: 14, weight: .bold))
    }
}

struct WorkoutDynamicIslandCompactTrailing: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>
    var body: some View {
        Text(context.state.formattedElapsed)
            .font(.system(.caption, design: .monospaced).bold())
            .foregroundStyle(.primary)
            .monospacedDigit()
    }
}

struct WorkoutDynamicIslandMinimalView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>
    var body: some View {
        Image(systemName: "flame.fill")
            .foregroundStyle(.orange)
            .font(.system(size: 12, weight: .bold))
    }
}

struct WorkoutDynamicIslandExpandedView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(red: 1.0, green: 0.52, blue: 0.15),
                                     Color(red: 0.88, green: 0.22, blue: 0.10)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 34, height: 34)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(context.attributes.workoutName)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    Text("In Progress")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(context.state.formattedElapsed)
                    .font(.system(.title3, design: .monospaced).bold())
                    .monospacedDigit()
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            Divider().padding(.horizontal, 12).padding(.top, 8)

            // Stats row
            HStack(spacing: 0) {
                expandedStat(value: "\(context.state.exerciseCount)", label: "Exercises", icon: "dumbbell.fill", color: .orange)
                Divider().frame(height: 36)
                expandedStat(value: "\(context.state.setCount)", label: "Sets Done", icon: "repeat", color: .blue)
                Divider().frame(height: 36)
                expandedStat(value: elapsedMinutes, label: "Minutes", icon: "clock.fill", color: .green)
            }
            .padding(.vertical, 10)

            // Current exercise
            if !context.state.currentExercise.isEmpty && context.state.currentExercise != "Getting started..." {
                Text("Now: \(context.state.currentExercise)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.bottom, 10)
            }
        }
    }

    private var elapsedMinutes: String {
        "\(context.state.elapsedSeconds / 60)"
    }

    private func expandedStat(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
            Text(value)
                .font(.system(.callout, design: .rounded).bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Widget Declaration

struct WorkoutLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            WorkoutLockScreenView(context: context)
                .containerBackground(.background, for: .widget)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    WorkoutDynamicIslandCompactLeading(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    WorkoutDynamicIslandCompactTrailing(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    WorkoutDynamicIslandExpandedView(context: context)
                }
            } compactLeading: {
                WorkoutDynamicIslandCompactLeading(context: context)
            } compactTrailing: {
                WorkoutDynamicIslandCompactTrailing(context: context)
            } minimal: {
                WorkoutDynamicIslandMinimalView(context: context)
            }
        }
    }
}
