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

    private var healthKitEnabled: Bool {
        settingsArray.first?.healthKitEnabled ?? false
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        Group {
            if !healthKitEnabled {
                healthKitDisabledView
            } else {
                healthDataList
            }
        }
        .navigationTitle("Health")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard healthKitEnabled else { return }
            await loadHealthData()
        }
        .refreshable {
            await loadHealthData()
        }
    }

    // MARK: - Main Content

    private var healthDataList: some View {
        List {
            Section {
                LazyVGrid(columns: columns, spacing: 12) {
                    stepsCard
                    heartRateCard
                    sleepCard
                    caloriesCard
                }
                .padding(.vertical, 4)
            }

            Section("Vitals") {
                HStack {
                    Label("HRV", systemImage: "waveform.path.ecg")
                    Spacer()
                    Text(hrv.map { "\(Int($0)) ms" } ?? "—")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                HStack {
                    Label("VO2 Max", systemImage: "lungs.fill")
                    Spacer()
                    Text(vo2Max.map { String(format: "%.1f", $0) } ?? "—")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            Section("Details") {
                NavigationLink {
                    StepsDetailView()
                } label: {
                    detailRow(icon: "figure.walk", color: .green, title: "Steps", subtitle: "Daily activity tracking")
                }
                NavigationLink {
                    HeartRateDetailView()
                } label: {
                    detailRow(icon: "heart.fill", color: .red, title: "Heart Rate", subtitle: "Resting heart rate trends")
                }
                NavigationLink {
                    SleepDetailView()
                } label: {
                    detailRow(icon: "bed.double.fill", color: .indigo, title: "Sleep", subtitle: "Duration and stages")
                }
            }

            if isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Summary Cards

    private var stepsCard: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 6)
                Circle()
                    .trim(from: 0, to: min(1.0, todaySteps / 10_000))
                    .stroke(Color.green.gradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "figure.walk")
                    .font(.title3)
                    .foregroundStyle(.green)
            }
            .frame(width: 52, height: 52)

            Text(HealthFormatters.formatSteps(todaySteps))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
            Text("Steps")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Steps: \(Int(todaySteps))")
    }

    private var heartRateCard: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(.red.opacity(0.12))
                Image(systemName: "heart.fill")
                    .font(.title3)
                    .foregroundStyle(.red)
            }
            .frame(width: 52, height: 52)

            Text(restingHR.map { "\(Int($0))" } ?? "—")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
            Text("Resting BPM")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Resting heart rate: \(restingHR.map { "\(Int($0)) BPM" } ?? "no data")")
    }

    private var sleepCard: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 6)
                Circle()
                    .trim(from: 0, to: min(1.0, sleepMinutes / 480))
                    .stroke(Color.indigo.gradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "bed.double.fill")
                    .font(.title3)
                    .foregroundStyle(.indigo)
            }
            .frame(width: 52, height: 52)

            Text(HealthFormatters.formatSleepShort(sleepMinutes))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
            Text("Sleep")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sleep: \(HealthFormatters.formatSleepDuration(sleepMinutes))")
    }

    private var caloriesCard: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(.orange.opacity(0.12))
                Image(systemName: "flame.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
            }
            .frame(width: 52, height: 52)

            Text("\(Int(activeCalories))")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
            Text("Active kcal")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Active calories: \(Int(activeCalories))")
    }

    // MARK: - Detail Row

    private func detailRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.gradient)
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Disabled State

    private var healthKitDisabledView: some View {
        ContentUnavailableView {
            Label("Apple Health Not Connected", systemImage: "heart.text.square")
        } description: {
            Text("Enable \"Sync with Apple Health\" in Settings to see your steps, heart rate, sleep, and other health data.")
        }
    }

    // MARK: - Data Loading

    private func loadHealthData() async {
        isLoading = true
        defer { isLoading = false }
        let hk = HealthKitManager.shared
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
