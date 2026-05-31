import SwiftUI

enum WeeklyMonthlyReportCardSections {

    static func cardioCard(snapshot: WeeklyMonthlyReportSnapshot, weightUnit: WeightUnit) -> some View {
        let zb = snapshot.cardioZoneBreakdown
        let zTotal = zb.reduce(0) { $0 + $1.seconds }
        let dom = zb.max(by: { $0.seconds < $1.seconds })?.zone
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Cardio", icon: "figure.run", color: AppTheme.Signal.runOrange)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                statTile(icon: "figure.run", value: "\(snapshot.cardioCount)", label: "Sessions", color: AppTheme.Signal.runOrange)
                statTile(icon: "ruler", value: weightUnit.distanceUnit.format(snapshot.cardioDistanceKm), label: "Distance", color: .teal)
                statTile(icon: "clock.fill", value: snapshot.formattedCardioDuration, label: "Time", color: .green)
                if let dom {
                    statTile(icon: "heart.fill", value: "Z\(dom.number)", label: "Top Zone", color: dom.color)
                }
            }
            if zTotal > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TIME IN ZONES")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(0.5)
                        .foregroundStyle(.secondary)
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            ForEach(zb, id: \.zone) { item in
                                Capsule()
                                    .fill(item.zone.color)
                                    .frame(width: max(4, geo.size.width * CGFloat(item.seconds / zTotal) - 2))
                            }
                        }
                    }
                    .frame(height: 10)
                }
                .padding(.top, 2)
            }
        }
        .appCard()
    }

    static func prsCard(snapshot: WeeklyMonthlyReportSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Personal Records", icon: "star.fill", color: .yellow)
            VStack(spacing: 0) {
                ForEach(Array(snapshot.prExerciseNames.prefix(5).enumerated()), id: \.offset) { idx, name in
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 1.00, green: 0.85, blue: 0.20), AppTheme.Signal.amber],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 38, height: 38)
                                .shadow(color: Color.yellow.opacity(0.45), radius: 5, y: 2)
                            Image(systemName: "star.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        Text(name)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                        Spacer()
                        Text("NEW PR")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(0.5)
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 1.00, green: 0.85, blue: 0.20), AppTheme.Signal.amber],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: Capsule()
                            )
                            .foregroundStyle(.white)
                            .shadow(color: Color.yellow.opacity(0.40), radius: 4, y: 2)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    if idx < min(snapshot.prExerciseNames.count, 5) - 1 { Divider().padding(.leading, 66) }
                }
                if snapshot.prExerciseNames.count > 5 {
                    Text("+ \(snapshot.prExerciseNames.count - 5) more PRs")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
            )
        }
        .appCard()
    }

    static func muscleGroupsCard(snapshot: WeeklyMonthlyReportSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Muscle Groups", icon: "figure.strengthtraining.traditional", color: .accentColor)
            let maxSets = Double(snapshot.muscleGroupSetCounts.first?.sets ?? 1)
            VStack(spacing: 12) {
                ForEach(snapshot.muscleGroupSetCounts.prefix(6), id: \.group) { item in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.16))
                                .frame(width: 28, height: 28)
                            MuscleIconView(group: item.group, color: Color.accentColor)
                                .frame(width: 14, height: 14)
                        }
                        Text(item.group.rawValue)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .frame(width: 76, alignment: .leading)
                        GradientProgressBar(value: Double(item.sets) / maxSets, color: .accentColor, height: 7)
                        Text("\(item.sets)")
                            .font(.system(size: 14, weight: .black, design: .rounded).monospacedDigit())
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 26, alignment: .trailing)
                    }
                }
            }
        }
        .appCard()
    }

    @ViewBuilder
    static func bodyWeightCard(snapshot: WeeklyMonthlyReportSnapshot, weightUnit: WeightUnit) -> some View {
        if let startW = snapshot.bodyWeightStart, let endW = snapshot.bodyWeightEnd {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Body Weight", icon: "scalemass.fill", color: .indigo)
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("START")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(0.4)
                                .foregroundStyle(.tertiary)
                            Text(weightUnit.format(startW))
                                .font(.system(size: 20, weight: .black, design: .rounded).monospacedDigit())
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.tertiary)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("LATEST")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(0.4)
                                .foregroundStyle(.tertiary)
                            Text(weightUnit.format(endW))
                                .font(.system(size: 20, weight: .black, design: .rounded).monospacedDigit())
                                .foregroundStyle(Color.indigo)
                        }
                        if let change = snapshot.bodyWeightChange {
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                Text("CHANGE")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .tracking(0.4)
                                    .foregroundStyle(.tertiary)
                                HStack(spacing: 3) {
                                    Image(systemName: change > 0 ? "arrow.up.right" : "arrow.down.right").imageScale(.small)
                                    Text(weightUnit.format(abs(change)))
                                }
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 9).padding(.vertical, 4)
                                .background(
                                    LinearGradient(
                                        colors: change > 0 ? [.red, Color(red: 0.78, green: 0.20, blue: 0.20)]
                                                            : [.green, AppTheme.Signal.recoveryShade],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    in: Capsule()
                                )
                                .shadow(color: (change > 0 ? Color.red : Color.green).opacity(0.40), radius: 4, y: 2)
                            }
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                }
                .background(
                    LinearGradient(
                        colors: [Color.indigo.opacity(0.08), Color(.tertiarySystemGroupedBackground)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.indigo.opacity(0.14), lineWidth: 0.5)
                )
            }
            .appCard()
        }
    }

    @ViewBuilder
    static func healthSummaryCard(
        avgSteps: Double?,
        avgSleepMinutes: Double?,
        avgRestingHR: Double?,
        avgHRV: Double?,
        prevAvgSteps: Double?,
        prevAvgSleepMinutes: Double?,
        prevAvgRestingHR: Double?,
        prevAvgHRV: Double?,
        isLoadingHealth: Bool
    ) -> some View {
        if avgSteps != nil || avgSleepMinutes != nil || avgRestingHR != nil || avgHRV != nil {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Health Summary", icon: "heart.fill", color: .red)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    if let steps = avgSteps {
                        healthTile(icon: "figure.walk", value: HealthFormatters.formatSteps(steps),
                                   label: "Avg Steps", color: .green,
                                   trend: WeeklyMonthlyReportEngine.trendInfo(current: steps, previous: prevAvgSteps, higherIsBetter: true))
                    }
                    if let sleep = avgSleepMinutes {
                        healthTile(icon: "bed.double.fill", value: HealthFormatters.formatSleepShort(sleep),
                                   label: "Avg Sleep", color: .indigo,
                                   trend: WeeklyMonthlyReportEngine.trendInfo(current: sleep, previous: prevAvgSleepMinutes, higherIsBetter: true))
                    }
                    if let hr = avgRestingHR {
                        healthTile(icon: "heart.fill", value: "\(Int(hr)) bpm",
                                   label: "Resting HR", color: .red,
                                   trend: WeeklyMonthlyReportEngine.trendInfo(current: hr, previous: prevAvgRestingHR, higherIsBetter: false))
                    }
                    if let hrv = avgHRV {
                        healthTile(icon: "waveform.path.ecg", value: "\(Int(hrv)) ms",
                                   label: "HRV", color: .purple,
                                   trend: WeeklyMonthlyReportEngine.trendInfo(current: hrv, previous: prevAvgHRV, higherIsBetter: true))
                    }
                }
            }
            .appCard()
        } else if isLoadingHealth {
            HStack(spacing: 12) {
                ProgressView().tint(.secondary)
                Text("Loading health data…").font(.subheadline).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCard()
        }
    }

    static func consistencyCard(snapshot: WeeklyMonthlyReportSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Consistency", icon: "flame.fill", color: .orange)
            VStack(spacing: 0) {
                consistencyRow(icon: "flame.fill", color: .orange, label: "Day Streak", value: "\(snapshot.currentStreak) days")
                if let wpw = snapshot.workoutsPerWeekAverage {
                    Divider().padding(.leading, 16)
                    consistencyRow(icon: "chart.bar.fill", color: .blue, label: "Per Week Avg",
                                   value: String(format: "%.1f workouts", wpw))
                }
                if let best = snapshot.bestDay {
                    Divider().padding(.leading, 16)
                    consistencyRow(icon: "star.fill", color: .yellow, label: "Best Day", value: best)
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
            )
        }
        .appCard()
    }

    private static func statTile(icon: String, value: String, label: String, color: Color, change: Double? = nil) -> some View {
        WeeklyMonthlyReportHeroSections.statTile(icon: icon, value: value, label: label, color: color, change: change)
    }

    private static func healthTile(icon: String, value: String, label: String, color: Color, trend: (icon: String, isGood: Bool)?) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(LinearGradient(colors: [color, color.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 38, height: 38)
                    .shadow(color: color.opacity(0.40), radius: 5, y: 2)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(value)
                        .font(.system(size: 15, weight: .black, design: .rounded).monospacedDigit())
                    if let trend {
                        Image(systemName: trend.icon).font(.caption2.weight(.bold))
                            .foregroundStyle(trend.isGood ? .green : .red)
                    }
                }
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(0.3)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .background(
            LinearGradient(
                colors: [color.opacity(0.10), Color(.tertiarySystemGroupedBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private static func consistencyRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(colors: [color, color.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 38, height: 38)
                    .shadow(color: color.opacity(0.40), radius: 5, y: 2)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text(label)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            Spacer()
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(color)
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
    }
}
