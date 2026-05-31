import SwiftUI
import SwiftData

struct HealthHubView: View {
    @Query(sort: \BodyWeightEntry.date, order: .reverse) private var bodyWeights: [BodyWeightEntry]
    @Query(sort: \WaterEntry.date, order: .reverse) private var waterEntries: [WaterEntry]
    @Query private var settingsArray: [UserSettings]
    @Environment(\.weightUnit) private var weightUnit

    private var latestWeightText: String {
        guard let w = bodyWeights.first?.weight else { return "—" }
        return weightUnit.formatShort(w)
    }

    private var hydration: HydrationSummary {
        HydrationSummary.make(
            entries: waterEntries,
            goalMl: settingsArray.first?.dailyWaterGoalMl ?? 2500
        )
    }

    private func mlShort(_ ml: Double) -> String {
        ml >= 1000 ? String(format: "%.1f L", ml / 1000) : "\(Int(ml)) ml"
    }

    private var waterTodayText: String {
        hydration.todayMl <= 0 ? "—" : mlShort(hydration.todayMl)
    }

    /// Signed change between the two most recent weigh-ins, e.g. "+0.3 kg"
    /// or "-0.5 kg". "—" until there are two entries to compare.
    private var weightTrendText: String {
        guard bodyWeights.count >= 2 else { return "—" }
        let delta = bodyWeights[0].weight - bodyWeights[1].weight
        return (delta >= 0 ? "+" : "") + weightUnit.formatShort(delta)
    }

    var body: some View {
        List {
            // ── Hero ──────────────────────────────────────────────────────
            Section {
                healthHeroCard
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
            }

            Section("Health") {
                NavigationLink { HealthDashboardView() } label: {
                    hubRow(icon: "heart.text.square", color: .red, title: "Health Dashboard", subtitle: "Steps, heart rate, sleep & more")
                }
                NavigationLink { CaffeineTrackerView() } label: {
                    hubRow(icon: "cup.and.saucer.fill", color: .brown, title: "Caffeine Tracker", subtitle: "Half-life decay & sleep readiness")
                }
                NavigationLink { WaterTrackerView() } label: {
                    hubRow(icon: "drop.fill", color: .cyan, title: "Water Tracker", subtitle: "Daily hydration tracking")
                }
                NavigationLink { CreatineTrackerView() } label: {
                    hubRow(icon: "pill.fill", color: .blue, title: "Creatine Tracker", subtitle: "Daily supplement tracking")
                }
            }

            Section("Body") {
                NavigationLink { BodyWeightView() } label: {
                    hubRow(icon: "scalemass", color: .blue, title: "Body Weight", subtitle: "Weigh-ins & trend line")
                }
                NavigationLink { BodyMeasurementsView() } label: {
                    hubRow(icon: "ruler", color: .teal, title: "Measurements", subtitle: "Body circumference tracking")
                }
                NavigationLink { BodyFatEstimateView() } label: {
                    hubRow(icon: "percent", color: .indigo, title: "Body Fat %", subtitle: "Navy method estimation")
                }
                NavigationLink { ProgressPhotosView() } label: {
                    hubRow(icon: "camera", color: .blue, title: "Progress Photos", subtitle: "Visual transformation")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .tabBackground(tint: .red, height: 280, intensity: 0.18)
        .navigationTitle("Health")
    }

    // MARK: - Hero

    /// Gives the Health tab the same hero treatment as the other tabs —
    /// a warm rose gradient (harmonising with the red tab tint) carrying
    /// the body-composition glance: latest weight, water today, weigh-ins.
    /// All from SwiftData, so no HealthKit fetch is needed on the hub.
    private var healthHeroCard: some View {
        HeroCard(palette: [
            Color(red: 0.93, green: 0.36, blue: 0.45),
            Color(red: 0.82, green: 0.30, blue: 0.52),
            Color(red: 0.62, green: 0.28, blue: 0.62)
        ]) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 6) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("Health")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .tracking(0.5)
                        .textCase(.uppercase)
                }

                HStack(spacing: 0) {
                    HeroStatCol(value: latestWeightText, label: "Weight", icon: "scalemass.fill")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 40)
                    HeroStatCol(value: weightTrendText, label: "Trend", icon: "arrow.up.arrow.down")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 40)
                    HeroStatCol(value: "\(bodyWeights.count)", label: "Weigh-ins", icon: "calendar")
                }
                .padding(.vertical, 12)
                .background(.ultraThinMaterial.opacity(0.55), in: RoundedRectangle(cornerRadius: AppTheme.miniCardRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.miniCardRadius, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 0.5)
                )

                hydrationGauge
            }
            .padding(20)
        }
        .frame(minHeight: 130)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Health summary")
    }

    /// Live hydration gauge in the hero — today's intake against the
    /// daily goal, so the Health tab opens on a glanceable daily metric
    /// (the body-tab analogue of the other heroes' rings) rather than a
    /// static number with no target.
    private var hydrationGauge: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                Text("HYDRATION")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.78))
                Spacer()
                Text("\(mlShort(hydration.todayMl)) / \(mlShort(hydration.goalMl))")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.22))
                    Capsule()
                        .fill(.white)
                        .frame(width: max(6, geo.size.width * hydration.progress))
                        .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                }
            }
            .frame(height: 7)
        }
    }
}
