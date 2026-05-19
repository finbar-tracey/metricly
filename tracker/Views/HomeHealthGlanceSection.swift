import SwiftUI

/// The 2-column health-tile grid on the home dashboard. Each tile deep-
/// links to the relevant detail view; tile state is read-only.
///
/// Extracted from HomeDashboardView during the sprint-2 decomposition.
/// All values are passed in by the parent rather than queried here, so
/// the parent stays the single source of truth for HK + SwiftData reads.
struct HomeHealthGlanceSection: View {
    let healthDataLoaded: Bool
    let animateRings: Bool

    let todaySteps: Double
    let sleepMinutes: Double
    let restingHR: Double?
    let hrv: Double?
    let activeCalories: Double
    let todayWaterMl: Double
    let waterProgress: Double
    let caffeineMg: Double
    let caffeineLimitMg: Double
    let creatineTakenToday: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "All Health Metrics", icon: "heart.circle.fill", color: .red)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                NavigationLink { StepsDetailView() } label: {
                    tile(icon: "figure.walk", color: .green,
                         value: HealthFormatters.formatSteps(todaySteps), label: "Steps",
                         progress: todaySteps / 10_000)
                }.buttonStyle(.pressableCard)

                NavigationLink { SleepDetailView() } label: {
                    tile(icon: "bed.double.fill", color: .indigo,
                         value: HealthFormatters.formatSleepShort(sleepMinutes), label: "Sleep",
                         progress: sleepMinutes / 480)
                }.buttonStyle(.pressableCard)

                NavigationLink { HeartRateDetailView() } label: {
                    tile(icon: "heart.fill", color: .red,
                         value: restingHR.map { "\(Int($0))" } ?? "—", label: "Resting HR",
                         progress: nil)
                }.buttonStyle(.pressableCard)

                NavigationLink { HealthDashboardView() } label: {
                    tile(icon: "waveform.path.ecg", color: .purple,
                         value: hrv.map { "\(Int($0)) ms" } ?? "—", label: "HRV",
                         progress: nil)
                }.buttonStyle(.pressableCard)

                NavigationLink { HealthDashboardView() } label: {
                    tile(icon: "flame.fill", color: .orange,
                         value: "\(Int(activeCalories))", label: "Active Cal",
                         progress: nil)
                }.buttonStyle(.pressableCard)

                NavigationLink { WaterTrackerView() } label: {
                    tile(icon: "drop.fill", color: .cyan,
                         value: "\(Int(todayWaterMl)) ml", label: "Water",
                         progress: waterProgress)
                }.buttonStyle(.pressableCard)

                if caffeineMg > 0.5 {
                    NavigationLink { CaffeineTrackerView() } label: {
                        tile(icon: "cup.and.saucer.fill", color: .brown,
                             value: "\(Int(caffeineMg)) mg", label: "Caffeine",
                             progress: caffeineLimitMg > 0 ? min(1.0, caffeineMg / caffeineLimitMg) : nil)
                    }.buttonStyle(.pressableCard)
                }

                NavigationLink { CreatineTrackerView() } label: {
                    tile(icon: "pill.fill", color: .blue,
                         value: creatineTakenToday ? "Taken" : "Not yet", label: "Creatine",
                         progress: creatineTakenToday ? 1.0 : 0)
                }.buttonStyle(.pressableCard)
            }
        }
        .appCard()
        .redacted(reason: !healthDataLoaded ? .placeholder : [])
        .animation(.easeInOut(duration: 0.3), value: healthDataLoaded)
    }

    private func tile(icon: String, color: Color, value: String, label: String, progress: Double?) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ZStack {
                    Circle().fill(color.opacity(0.18))
                    if let progress {
                        Circle()
                            .trim(from: 0, to: animateRings ? min(1.0, progress) : 0)
                            .stroke(color.gradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 0.8), value: animateRings)
                    }
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(color)
                }
                .frame(width: 44, height: 44)
                Spacer()
                if let progress {
                    Text("\(Int(min(1, progress) * 100))%")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(color.opacity(0.12), in: Capsule())
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .tracking(0.3)
                    .textCase(.uppercase)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            LinearGradient(
                colors: [color.opacity(0.10), Color(.tertiarySystemGroupedBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(color.opacity(0.18), lineWidth: 0.5)
        )
    }
}
