import SwiftUI
import SwiftData

struct HealthDashboardView: View {
    @Query private var settingsArray: [UserSettings]

    @State private var todaySteps: Double = 0
    @State private var restingHR: Double?
    @State private var hrStats: (min: Double, max: Double, avg: Double)?
    @State private var sleepMinutes: Double = 0
    @State private var sleepInBed: Date?
    @State private var sleepWakeUp: Date?
    @State private var activeCalories: Double = 0
    @State private var hrv: Double?
    @State private var vo2Max: Double?
    @State private var isLoading = true

    private var healthKitEnabled: Bool { settingsArray.first?.healthKitEnabled ?? false }

    var body: some View {
        Group {
            if !healthKitEnabled {
                healthKitDisabledView
            } else {
                healthContent
            }
        }
        .navigationTitle("Health")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard healthKitEnabled else { return }
            await loadHealthData()
        }
        .refreshable { await loadHealthData() }
    }

    // MARK: - Main Content

    private var healthContent: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    summaryGrid
                    vitalsCard
                    detailLinksCard
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Summary Grid

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            healthMetricCard(
                icon: "figure.walk",
                color: .green,
                value: HealthFormatters.formatSteps(todaySteps),
                label: "Steps",
                ring: min(1.0, todaySteps / 10_000),
                ringColor: .green
            )
            healthMetricCard(
                icon: "heart.fill",
                color: .red,
                value: restingHR.map { "\(Int($0))" } ?? "—",
                label: "Resting BPM",
                ring: nil,
                ringColor: .red
            )
            healthMetricCard(
                icon: "bed.double.fill",
                color: .indigo,
                value: HealthFormatters.formatSleepShort(sleepMinutes),
                label: "Sleep",
                ring: min(1.0, sleepMinutes / 480),
                ringColor: .indigo
            )
            healthMetricCard(
                icon: "flame.fill",
                color: .orange,
                value: "\(Int(activeCalories))",
                label: "Active kcal",
                ring: nil,
                ringColor: .orange
            )
        }
    }

    private func healthMetricCard(
        icon: String,
        color: Color,
        value: String,
        label: String,
        ring: Double?,
        ringColor: Color
    ) -> some View {
        VStack(spacing: 14) {
            ZStack {
                if let ring = ring {
                    Circle()
                        .stroke(ringColor.opacity(0.16), lineWidth: 7)
                    Circle()
                        .trim(from: 0, to: ring)
                        .stroke(
                            ringColor.gradient,
                            style: StrokeStyle(lineWidth: 7, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.6), value: ring)
                        .shadow(color: ringColor.opacity(0.45), radius: 5, y: 1)
                } else {
                    Circle().fill(color.opacity(0.16))
                    Circle().stroke(color.opacity(0.18), lineWidth: 1)
                }
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(color)
            }
            .frame(width: 60, height: 60)

            VStack(spacing: 3) {
                Text(value)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .monospacedDigit()
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .tracking(0.3)
                    .textCase(.uppercase)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(
            LinearGradient(
                colors: [color.opacity(0.10), Color(.secondarySystemGroupedBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .stroke(color.opacity(0.18), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.10), radius: 16, x: 0, y: 5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Vitals Card

    private var vitalsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Vitals", icon: "waveform.path.ecg", color: .purple)

            VStack(spacing: 0) {
                vitalsRow(icon: "waveform.path.ecg", color: .purple, label: "HRV",
                          value: hrv.map { "\(Int($0)) ms" } ?? "—")
                Divider().padding(.leading, 16)
                vitalsRow(icon: "lungs.fill", color: .teal, label: "VO2 Max",
                          value: vo2Max.map { String(format: "%.1f ml/kg/min", $0) } ?? "—")
                if let stats = hrStats {
                    Divider().padding(.leading, 16)
                    vitalsRow(icon: "arrow.up.arrow.down", color: .orange, label: "HR Range Today",
                              value: "\(Int(stats.min))–\(Int(stats.max)) bpm")
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    private func vitalsRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.72)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
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
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    // MARK: - Detail Links Card

    private var detailLinksCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Details", icon: "chart.line.uptrend.xyaxis", color: .accentColor)

            VStack(spacing: 0) {
                NavigationLink { StepsDetailView() } label: {
                    detailRow(icon: "figure.walk", color: .green, title: "Steps", subtitle: "Daily activity tracking")
                }
                .buttonStyle(.pressableCard)
                Divider().padding(.leading, 70)
                NavigationLink { HeartRateDetailView() } label: {
                    detailRow(icon: "heart.fill", color: .red, title: "Heart Rate", subtitle: "Resting heart rate trends")
                }
                .buttonStyle(.pressableCard)
                Divider().padding(.leading, 70)
                NavigationLink { SleepDetailView() } label: {
                    detailRow(icon: "bed.double.fill", color: .indigo, title: "Sleep", subtitle: "Duration and stages")
                }
                .buttonStyle(.pressableCard)
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.cardHairline, lineWidth: 0.5)
            )
        }
        .appCard()
    }

    private func detailRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.72)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .shadow(color: color.opacity(0.40), radius: 6, y: 3)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    // MARK: - Disabled State

    private var healthKitDisabledView: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.red.opacity(0.20), Color.red.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 110, height: 110)
                    .overlay(Circle().stroke(Color.red.opacity(0.18), lineWidth: 1))
                Image(systemName: "heart.text.square")
                    .font(.system(size: 46, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.red, Color(red: 0.85, green: 0.20, blue: 0.30)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            VStack(spacing: 8) {
                Text("Apple Health Not Connected")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Enable \"Sync with Apple Health\" in Settings to see your steps, heart rate, sleep, and other health data.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            Spacer()
        }
    }

    // MARK: - Data Loading

    private func loadHealthData() async {
        isLoading = true
        defer { isLoading = false }
        let hk = HealthDataCache.shared
        let today = Date.now

        async let stepsResult = hk.fetchSteps(for: today)
        async let hrResult = hk.fetchRestingHeartRate(for: today)
        async let hrStatsResult = hk.fetchHeartRateStats(for: today)
        async let sleepResult = hk.fetchSleep(for: today)
        async let caloriesResult = hk.fetchActiveEnergy(for: today)
        async let hrvResult = hk.fetchHRV(for: today)
        async let vo2Result = hk.fetchLatestVO2Max()

        todaySteps = (try? await stepsResult) ?? 0
        restingHR = try? await hrResult
        hrStats = try? await hrStatsResult
        let sleep = try? await sleepResult
        sleepMinutes = sleep?.totalMinutes ?? 0
        sleepInBed = sleep?.inBed
        sleepWakeUp = sleep?.wakeUp
        activeCalories = (try? await caloriesResult) ?? 0
        hrv = try? await hrvResult
        vo2Max = try? await vo2Result
    }
}
