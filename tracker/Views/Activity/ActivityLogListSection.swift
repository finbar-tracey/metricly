import SwiftUI

enum ActivityLogListSection {

    static func emptyStateCard() -> some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(Color.green.opacity(0.12)).frame(width: 70, height: 70)
                Image(systemName: "figure.mixed.cardio")
                    .font(.system(size: 28, weight: .semibold)).foregroundStyle(.green)
            }
            VStack(spacing: 6) {
                Text("No Activities Yet").font(.headline)
                Text("Log walks, rides, stretching, and other activities. Workouts synced from Apple Health will also appear.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
        .appCard()
    }

    static func timelineCard(
        allDates: [Date],
        activities: [ManualActivity],
        externalWorkouts: [ExternalWorkout],
        weightUnit: WeightUnit,
        onDelete: @escaping (ManualActivity) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "History", icon: "clock.fill", color: .secondary)

            VStack(spacing: 12) {
                ForEach(allDates, id: \.self) { date in
                    daySection(
                        for: date,
                        activities: activities,
                        externalWorkouts: externalWorkouts,
                        weightUnit: weightUnit,
                        onDelete: onDelete
                    )
                }
            }
        }
        .appCard()
    }

    private static func daySection(
        for date: Date,
        activities: [ManualActivity],
        externalWorkouts: [ExternalWorkout],
        weightUnit: WeightUnit,
        onDelete: @escaping (ManualActivity) -> Void
    ) -> some View {
        let dayExternal = externalWorkouts.filter {
            !$0.isFromThisApp && Calendar.current.isDate($0.startDate, inSameDayAs: date)
        }.sorted { $0.startDate > $1.startDate }

        let dayManual = activities.filter {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }

        return VStack(alignment: .leading, spacing: 0) {
            Text(date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemGroupedBackground).opacity(0.6))

            ForEach(dayExternal) { workout in
                externalWorkoutRow(workout, weightUnit: weightUnit)
                Divider().padding(.leading, 62)
            }

            ForEach(Array(dayManual.enumerated()), id: \.element.id) { idx, activity in
                activityRow(activity)
                    .contextMenu {
                        Button(role: .destructive) { onDelete(activity) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                if idx < dayManual.count - 1 || !dayExternal.isEmpty {
                    Divider().padding(.leading, 62)
                }
            }
        }
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private static func activityRow(_ activity: ManualActivity) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(colorFor(activity.type).opacity(0.12)).frame(width: 40, height: 40)
                Image(systemName: activity.type.icon)
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(colorFor(activity.type))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.type.rawValue).font(.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                    Text("\(activity.durationMinutes) min").font(.caption).foregroundStyle(.secondary)
                    if let cal = activity.caloriesBurned {
                        Text("· \(cal) cal").font(.caption).foregroundStyle(.secondary)
                    }
                    Text(activity.date, format: .dateTime.hour().minute())
                        .font(.caption).foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
    }

    private static func externalWorkoutRow(_ workout: ExternalWorkout, weightUnit: WeightUnit) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color.teal.opacity(0.12)).frame(width: 40, height: 40)
                Image(systemName: workout.icon)
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(.teal)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(workout.displayName).font(.subheadline.weight(.semibold))
                    Text(workout.sourceName).font(.caption2).foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(.teal.opacity(0.6), in: Capsule())
                }
                HStack(spacing: 6) {
                    Text(formatDuration(workout.duration)).font(.caption).foregroundStyle(.secondary)
                    if let cal = workout.totalCalories, cal > 0 {
                        Text("· \(Int(cal)) cal").font(.caption).foregroundStyle(.secondary)
                    }
                    if let dist = workout.totalDistance, dist > 0 {
                        let distUnit = weightUnit.distanceUnit
                        let distKm = dist / 1000
                        Text("· \(String(format: "%.1f", distUnit.display(distKm))) \(distUnit.label)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text(workout.startDate, format: .dateTime.hour().minute())
                        .font(.caption).foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
    }

    private static func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        return mins >= 60 ? "\(mins / 60)h \(mins % 60)m" : "\(mins) min"
    }

    private static func colorFor(_ type: ManualActivity.ActivityType) -> Color {
        switch type.color {
        case "green": return .green
        case "orange": return .orange
        case "blue": return .blue
        case "cyan": return .cyan
        case "brown": return .brown
        case "purple": return .purple
        case "indigo": return .indigo
        case "red": return .red
        default: return .gray
        }
    }
}
