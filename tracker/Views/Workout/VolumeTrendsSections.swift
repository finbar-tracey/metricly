import SwiftUI
import Charts

enum VolumeTrendsSections {

    static func heroCard(
        totalVolumeThisWeek: Double,
        totalVolumeLastWeek: Double,
        volumeChange: Double,
        workoutsThisWeek: Int,
        formatVolume: @escaping (Double) -> String
    ) -> some View {
        HeroCard(palette: [
            Color.blue,
            Color.blue.opacity(0.78),
            Color(red: 0.10, green: 0.40, blue: 0.85)
        ]) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial.opacity(0.7))
                            .frame(width: 56, height: 56)
                            .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.5))
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 24, weight: .bold)).foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("This Week")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(0.5)
                            .textCase(.uppercase)
                            .foregroundStyle(.white.opacity(0.75))
                        Text(formatVolume(totalVolumeThisWeek))
                            .font(.system(size: 38, weight: .black, design: .rounded))
                            .foregroundStyle(.white).monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    Spacer()
                    if totalVolumeLastWeek > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: volumeChange >= 0 ? "arrow.up" : "arrow.down")
                                .font(.caption.bold())
                            Text(String(format: "%.0f%%", abs(volumeChange))).font(.caption.bold())
                        }
                        .padding(.horizontal, 11).padding(.vertical, 5)
                        .background(.ultraThinMaterial.opacity(0.65), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 0.5))
                        .foregroundStyle(.white)
                    }
                }

                HStack(spacing: 0) {
                    HeroStatCol(value: formatVolume(totalVolumeLastWeek), label: "Last Week")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 36)
                    HeroStatCol(
                        value: totalVolumeLastWeek > 0 ? String(format: "%+.0f%%", volumeChange) : "—",
                        label: "WoW"
                    )
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 36)
                    HeroStatCol(value: "\(workoutsThisWeek)", label: "Workouts")
                }
                .padding(.vertical, 12)
                .background(.ultraThinMaterial.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.white.opacity(0.18), lineWidth: 0.5)
                )
            }
            .padding(20)
        }
    }

    static func volumeChartCard(
        timeRange: Binding<VolumeTrendPeriod>,
        volumeData: [VolumePoint],
        unit: WeightUnit
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Volume Trend", icon: "chart.bar.fill", color: .blue)

            HStack(spacing: 6) {
                ForEach(VolumeTrendPeriod.allCases, id: \.self) { range in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) { timeRange.wrappedValue = range }
                    } label: {
                        Text(range.rawValue)
                            .font(.caption.bold())
                            .padding(.horizontal, 16).padding(.vertical, 7)
                            .background {
                                if timeRange.wrappedValue == range {
                                    Capsule().fill(
                                        LinearGradient(
                                            colors: [.blue, AppTheme.Signal.calm],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: .blue.opacity(0.40), radius: 6, y: 3)
                                } else {
                                    Capsule().fill(Color(.secondarySystemFill))
                                }
                            }
                            .foregroundStyle(timeRange.wrappedValue == range ? .white : .primary)
                    }
                    .buttonStyle(.pressableCard)
                }
                Spacer()
            }

            if volumeData.isEmpty {
                Text("Not enough data yet.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 40)
            } else {
                Chart(volumeData) { point in
                    BarMark(
                        x: .value("Period", point.date, unit: timeRange.wrappedValue == .weekly ? .weekOfYear : .month),
                        y: .value("Volume", unit.display(point.volume))
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                AppTheme.Signal.calm,
                                Color(red: 0.45, green: 0.30, blue: 0.95)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(6)
                }
                .chartYAxisLabel(unit.label)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisGridLine().foregroundStyle(AppTheme.chartGrid)
                        AxisValueLabel().font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(AppTheme.chartGrid)
                        AxisValueLabel().font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .frame(height: 220).padding(.vertical, 12)
            }
        }
        .appCard()
    }

    static func muscleBreakdownCard(
        muscleVolumeData: [(MuscleGroup, Double)],
        formatVolume: @escaping (Double) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Volume by Muscle (30 days)", icon: "figure.strengthtraining.traditional", color: .blue)

            let maxVol = muscleVolumeData.map(\.1).max() ?? 1

            VStack(spacing: 0) {
                ForEach(Array(muscleVolumeData.enumerated()), id: \.element.0) { idx, pair in
                    let (group, volume) = pair
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue.opacity(0.26), Color.blue.opacity(0.12)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 34, height: 34)
                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.blue.opacity(0.28), lineWidth: 0.5))
                            MuscleIconView(group: group, color: Color.blue)
                                .frame(width: 14, height: 14)
                        }
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(group.rawValue).font(.subheadline.weight(.medium))
                                Spacer()
                                Text(formatVolume(volume))
                                    .font(.caption.bold().monospacedDigit()).foregroundStyle(.secondary)
                            }
                            GradientProgressBar(value: volume / maxVol, color: .blue, height: 5)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    if idx < muscleVolumeData.count - 1 { Divider().padding(.leading, 64) }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }
}
