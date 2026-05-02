import SwiftUI
import HealthKit

// MARK: - Activity picker

struct WatchCardioStartView: View {
    @EnvironmentObject private var sessionManager: WatchWorkoutSessionManager
    @EnvironmentObject private var connectivity:   WatchConnectivityManager

    @State private var selectedType: WatchCardioType = .run

    var body: some View {
        if sessionManager.isRunning {
            WatchCardioActiveView()
        } else {
            VStack(spacing: 10) {
                Picker("Activity", selection: $selectedType) {
                    ForEach(WatchCardioType.allCases) { type in
                        Label(type.shortName, systemImage: type.icon).tag(type)
                    }
                }
                .pickerStyle(.wheel)

                Button {
                    startCardio()
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(selectedType.color)
            }
            .padding()
            .navigationTitle("Cardio")
        }
    }

    private func startCardio() {
        Task {
            await sessionManager.requestAuthorization()
            try? await sessionManager.startSession(
                activityType: selectedType.hkType,
                isIndoor: selectedType.isIndoor
            )
        }
    }
}

// MARK: - Live cardio view (paged metrics)

struct WatchCardioActiveView: View {
    @EnvironmentObject private var sessionManager: WatchWorkoutSessionManager
    @State private var showingFinish = false
    @State private var startDate     = Date.now

    // Derive activity from session
    private var cardioType: WatchCardioType {
        WatchCardioType.from(hkType: sessionManager.activityType,
                             isIndoor: sessionManager.isIndoor)
    }

    var body: some View {
        TabView {
            // Page 1: Primary metrics grid
            metricsPage

            // Page 2: HR zone detail
            hrPage

            // Page 3: Controls
            controlsPage
        }
        .tabViewStyle(.page)
        .navigationTitle(cardioType.shortName)
        .onAppear { startDate = Date.now.addingTimeInterval(TimeInterval(-sessionManager.elapsedSeconds)) }
        .sheet(isPresented: $showingFinish) {
            WatchCardioSummaryView(cardioType: cardioType) {
                finishCardio()
            }
        }
    }

    // MARK: - Pages

    private var metricsPage: some View {
        VStack(spacing: 0) {
            // Top: HR
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.caption.bold())
                    .foregroundStyle(hrColor)
                Text(sessionManager.heartRate > 0 ? "\(Int(sessionManager.heartRate))" : "--")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("bpm")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                // Pause / resume
                Button {
                    if sessionManager.isPaused { sessionManager.resume() }
                    else { sessionManager.pause() }
                } label: {
                    Image(systemName: sessionManager.isPaused ? "play.fill" : "pause.fill")
                        .font(.caption.bold())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.top, 4)

            Divider()

            // 2×2 metric grid
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 8
            ) {
                metricCell(
                    value: formatDuration(sessionManager.elapsedSeconds),
                    label: "TIME",
                    color: .primary
                )
                metricCell(
                    value: distanceLabel,
                    label: "KM",
                    color: cardioType.color
                )
                metricCell(
                    value: paceLabel,
                    label: "PACE",
                    color: .blue
                )
                metricCell(
                    value: "\(Int(sessionManager.activeCalories))",
                    label: "CAL",
                    color: .orange
                )
            }
            .padding(8)
        }
    }

    private var hrPage: some View {
        VStack(spacing: 8) {
            Text(sessionManager.heartRate > 0 ? "\(Int(sessionManager.heartRate))" : "--")
                .font(.system(size: 56, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(hrColor)

            Text(sessionManager.heartRateZone.rawValue)
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(hrColor.opacity(0.2), in: Capsule())

            if sessionManager.maxHeartRate > 0 {
                Text("Peak: \(Int(sessionManager.maxHeartRate)) bpm")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "heart.fill")
                .font(.system(size: 22))
                .foregroundStyle(hrColor)
                .symbolEffect(.pulse.byLayer, options: .repeating)
        }
    }

    private var controlsPage: some View {
        VStack(spacing: 12) {
            Button {
                if sessionManager.isPaused { sessionManager.resume() }
                else { sessionManager.pause() }
            } label: {
                Label(
                    sessionManager.isPaused ? "Resume" : "Pause",
                    systemImage: sessionManager.isPaused ? "play.fill" : "pause.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(sessionManager.isPaused ? .green : .yellow)

            Button {
                showingFinish = true
            } label: {
                Label("End", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding()
    }

    // MARK: - Helpers

    private func metricCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.secondary)
                .kerning(0.5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private var distanceLabel: String {
        String(format: "%.2f", sessionManager.distanceMeters / 1000)
    }

    private var paceLabel: String {
        formatPace(
            distanceMeters: sessionManager.distanceMeters,
            elapsedSeconds: sessionManager.elapsedSeconds,
            useKm: true
        )
    }

    private var hrColor: Color {
        switch sessionManager.heartRateZone {
        case .resting: return .gray
        case .fat:     return .blue
        case .cardio:  return .green
        case .peak:    return .orange
        case .max:     return .red
        }
    }

    // MARK: - Finish

    private func finishCardio() {
        let payload = WatchCardioPayload(
            id:              UUID(),
            date:            Date.now,
            activityTypeRaw: cardioType.payloadRaw,
            durationSeconds: Double(sessionManager.elapsedSeconds),
            distanceMeters:  sessionManager.distanceMeters,
            avgHeartRate:    sessionManager.heartRate > 0 ? sessionManager.heartRate : nil,
            maxHeartRate:    sessionManager.maxHeartRate > 0 ? sessionManager.maxHeartRate : nil,
            calories:        sessionManager.activeCalories > 0 ? sessionManager.activeCalories : nil,
            elevationGain:   0
        )
        Task {
            try? await sessionManager.endSession()
            WatchConnectivityManager.shared.sendCardio(payload)
        }
        showingFinish = false
    }
}

// MARK: - Summary screen

struct WatchCardioSummaryView: View {
    let cardioType: WatchCardioType
    let onFinish:   () -> Void

    @EnvironmentObject private var sessionManager: WatchWorkoutSessionManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Image(systemName: cardioType.icon)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(cardioType.color)

                Text(cardioType.shortName)
                    .font(.headline)

                Divider()

                summaryRow("Distance", String(format: "%.2f km", sessionManager.distanceMeters / 1000))
                summaryRow("Duration", formatDuration(sessionManager.elapsedSeconds))
                summaryRow("Pace", formatPace(distanceMeters: sessionManager.distanceMeters,
                                              elapsedSeconds: sessionManager.elapsedSeconds,
                                              useKm: true) + " /km")
                if sessionManager.heartRate > 0 {
                    summaryRow("Avg HR", "\(Int(sessionManager.heartRate)) bpm")
                }
                if sessionManager.maxHeartRate > 0 {
                    summaryRow("Max HR", "\(Int(sessionManager.maxHeartRate)) bpm")
                }
                if sessionManager.activeCalories > 0 {
                    summaryRow("Calories", "\(Int(sessionManager.activeCalories)) kcal")
                }

                Button("Save") {
                    onFinish()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding()
        }
        .navigationTitle("Done!")
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.caption.bold())
        }
    }
}

// MARK: - WatchCardioType (Watch-local mirror of CardioType)

enum WatchCardioType: String, CaseIterable, Identifiable {
    case run     = "Outdoor Run"
    case treadmill = "Indoor Run"
    case walk    = "Outdoor Walk"
    case cycle   = "Outdoor Cycle"

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .run:       return "Run"
        case .treadmill: return "Treadmill"
        case .walk:      return "Walk"
        case .cycle:     return "Cycle"
        }
    }

    var icon: String {
        switch self {
        case .run, .treadmill: return "figure.run"
        case .walk:            return "figure.walk"
        case .cycle:           return "figure.outdoor.cycle"
        }
    }

    var color: Color {
        switch self {
        case .run, .treadmill: return .orange
        case .walk:            return .green
        case .cycle:           return .blue
        }
    }

    var isIndoor: Bool { self == .treadmill }

    var hkType: HKWorkoutActivityType {
        switch self {
        case .run, .treadmill: return .running
        case .walk:            return .walking
        case .cycle:           return .cycling
        }
    }

    /// Maps back to iPhone's CardioType.rawValue
    var payloadRaw: String {
        switch self {
        case .run:       return "Outdoor Run"
        case .treadmill: return "Indoor Run"
        case .walk:      return "Outdoor Walk"
        case .cycle:     return "Outdoor Cycle"
        }
    }

    static func from(hkType: HKWorkoutActivityType, isIndoor: Bool) -> WatchCardioType {
        switch hkType {
        case .running:  return isIndoor ? .treadmill : .run
        case .walking:  return .walk
        case .cycling:  return .cycle
        default:        return .run
        }
    }
}
