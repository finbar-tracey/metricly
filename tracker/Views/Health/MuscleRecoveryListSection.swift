import SwiftUI

enum MuscleRecoveryListSection {

    static func externalActivityCard(
        externalWorkouts: [ExternalWorkout],
        weightUnit: WeightUnit
    ) -> some View {
        GroupedListCard(
            title: String(localized: "External Activity",
                          comment: "Section header above the list of workouts pulled from HealthKit / Strava"),
            icon: "figure.run",
            color: .orange
        ) {
            ForEach(Array(externalWorkouts.prefix(5).enumerated()), id: \.element.id) { idx, workout in
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.orange, AppTheme.Signal.actionOrange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                            .shadow(color: .orange.opacity(0.40), radius: 5, y: 2)
                        Image(systemName: workout.icon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(workout.displayName)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                        HStack(spacing: 6) {
                            Text(workout.sourceName)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            if workout.duration > 0 {
                                Text(formatDuration(workout.duration))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            if let dist = workout.totalDistance, dist > 0 {
                                Text(String(format: "%.1f %@",
                                     weightUnit.distanceUnit.display(dist / 1000),
                                     weightUnit.distanceUnit.label))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    Spacer()
                    Text(workout.startDate, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                if idx < min(externalWorkouts.count, 5) - 1 {
                    Divider().padding(.leading, 64)
                }
            }
        }
    }

    static func sorenessReportsCard(activeSorenessReports: [SorenessEntry]) -> some View {
        GroupedListCard(
            title: String(localized: "Reported Soreness",
                          comment: "Section header above the user's recent post-workout soreness reports"),
            icon: "figure.cooldown",
            color: .purple,
            footnote: String(localized: "From your post-workout check-in. Counts for 48 hours.",
                             comment: "Footnote under the Reported Soreness section")
        ) {
            ForEach(Array(activeSorenessReports.enumerated()), id: \.element.id) { idx, report in
                sorenessRow(report)
                if idx < activeSorenessReports.count - 1 {
                    Divider().padding(.leading, 52)
                }
            }
        }
    }

    static func muscleGroupsCard(recoveryResult: RecoveryResult) -> some View {
        let sorted = recoveryResult.muscleResults.sorted { $0.freshness > $1.freshness }
        return GroupedListCard(
            title: String(localized: "By Muscle Group",
                          comment: "Section header above the per-muscle freshness breakdown"),
            icon: "figure.strengthtraining.traditional",
            color: .accentColor
        ) {
            ForEach(Array(sorted.enumerated()), id: \.element.id) { idx, result in
                muscleRow(result)
                if idx < sorted.count - 1 {
                    Divider().padding(.leading, 62)
                }
            }
        }
    }

    static func suggestedCard(recoveryResult: RecoveryResult) -> some View {
        let ready = recoveryResult.muscleResults.filter { $0.freshness >= 0.8 }
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(
                title: String(localized: "Suggested Today",
                              comment: "Section header above the engine's per-muscle 'train this' recommendations"),
                icon: "checkmark.circle.fill", color: .green
            )

            if ready.isEmpty {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.orange, AppTheme.Signal.actionOrange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                            .shadow(color: .orange.opacity(0.40), radius: 6, y: 3)
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    Text(String(
                        localized: "All muscles are still recovering. Consider a rest day or light cardio.",
                        comment: "Shown under Suggested Today when every muscle group is below the ready threshold"
                    ))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(ready) { result in
                        HStack(spacing: 9) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.green.opacity(0.30), Color.green.opacity(0.14)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 28, height: 28)
                                    .overlay(Circle().stroke(Color.green.opacity(0.30), lineWidth: 0.5))
                                MuscleIconView(group: result.group, color: .green)
                                    .frame(width: 14, height: 14)
                            }
                            Text(result.group.rawValue)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(
                            LinearGradient(
                                colors: [Color.green.opacity(0.16), Color.green.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.green.opacity(0.20), lineWidth: 0.5)
                        )
                    }
                }
            }
        }
        .appCard()
    }

    // MARK: - Rows

    private static func sorenessRow(_ report: SorenessEntry) -> some View {
        let level = SorenessEntry.Level(rawValue: max(0, min(4, report.level))) ?? .none
        let tint = SorenessEntry.Level.tint(forLevel: report.level)
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.26), tint.opacity(0.12)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                    .overlay(Circle().stroke(tint.opacity(0.28), lineWidth: 0.5))
                Image(systemName: level.sfSymbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(report.group.rawValue)
                    .font(.subheadline.weight(.semibold))
                Text(level.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(report.date.formatted(.relative(presentation: .named, unitsStyle: .abbreviated)))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private static func muscleRow(_ result: MuscleFatigueResult) -> some View {
        let color = RecoveryEngine.freshnessColor(result.freshness)
        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.20), color.opacity(0.10)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 42, height: 42)
                    .overlay(Circle().stroke(color.opacity(0.20), lineWidth: 0.5))
                MuscleIconView(group: result.group, color: color)
                    .frame(width: 18, height: 18)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(result.group.rawValue)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Spacer()
                    Text(RecoveryEngine.freshnessLabel(result.freshness).uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(0.4)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9).padding(.vertical, 3)
                        .background(
                            LinearGradient(
                                colors: [color, color.opacity(0.72)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: Capsule()
                        )
                        .shadow(color: color.opacity(0.40), radius: 4, y: 2)
                }
                GradientProgressBar(value: result.freshness, color: color, height: 7)
                if let last = result.lastTrained {
                    Text(RecoveryEngine.timeAgoText(from: last))
                        .font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text(String(
                        localized: "Not trained recently",
                        comment: "Shown in the by-muscle breakdown when the muscle hasn't been trained in the lookback window"
                    ))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private static func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        if mins >= 60 { let h = mins / 60; let m = mins % 60; return "\(h)h \(m)m" }
        return "\(mins)m"
    }
}
