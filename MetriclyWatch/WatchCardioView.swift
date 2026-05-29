import SwiftUI
import HealthKit
import WatchKit

// MARK: - Activity picker

struct WatchCardioStartView: View {
    @EnvironmentObject private var sessionManager: WatchWorkoutSessionManager
    @EnvironmentObject private var connectivity:   WatchConnectivityManager

    var body: some View {
        if sessionManager.isRunning {
            WatchCardioActiveView()
        } else {
            // List of activities — tap any row to start. Wheel picker felt
            // dated and required two interactions (scroll + tap Start).
            // One-tap start is faster on the gym floor.
            List {
                ForEach(WatchCardioType.allCases) { type in
                    Button {
                        WKInterfaceDevice.current().play(.start)
                        startCardio(type: type)
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(type.color.opacity(0.20))
                                    .frame(width: 32, height: 32)
                                Image(systemName: type.icon)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(type.color)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(type.shortName)
                                    .font(.subheadline.weight(.semibold))
                                Text(type.isIndoor ? "Indoor" : "Outdoor")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "play.fill")
                                .font(.caption2)
                                .foregroundStyle(type.color)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Cardio")
        }
    }

    private func startCardio(type: WatchCardioType) {
        Task {
            await sessionManager.requestAuthorization()
            try? await sessionManager.startSession(
                activityType: type.hkType,
                isIndoor: type.isIndoor
            )
            sessionManager.publishActiveState(
                startedAt: .now,
                name: type.rawValue
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
        // Send the actual session start as the payload's date — the
        // phone's `persistCardio` populates `CardioSession` from this
        // and the iPhone treats `date` as the session start. Falling
        // back to `.now` here would stamp the finish time onto the
        // session and re-introduce the v1.5-review timestamp bug.
        let payload = WatchCardioPayload(
            id:              UUID(),
            date:            sessionManager.startDate ?? Date.now,
            activityTypeRaw: cardioType.payloadRaw,
            durationSeconds: Double(sessionManager.elapsedSeconds),
            distanceMeters:  sessionManager.distanceMeters,
            // True session average from HKLiveWorkoutBuilder; falls back to
            // the latest sample only if the builder hasn't produced a mean
            // yet (very short sessions). See WatchWorkoutSessionManager.
            avgHeartRate: {
                if sessionManager.averageHeartRate > 0 { return sessionManager.averageHeartRate }
                if sessionManager.heartRate > 0        { return sessionManager.heartRate }
                return nil
            }(),
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
    case run         = "Outdoor Run"
    case treadmill   = "Indoor Run"
    case walk        = "Outdoor Walk"
    case indoorWalk  = "Indoor Walk"
    case cycle       = "Outdoor Cycle"

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .run:        return "Run"
        case .treadmill:  return "Treadmill"
        case .walk:       return "Walk"
        case .indoorWalk: return "Indoor Walk"
        case .cycle:      return "Cycle"
        }
    }

    var icon: String {
        switch self {
        case .run, .treadmill:      return "figure.run"
        case .walk, .indoorWalk:    return "figure.walk"
        case .cycle:                return "figure.outdoor.cycle"
        }
    }

    var color: Color {
        switch self {
        case .run, .treadmill:      return .orange
        case .walk, .indoorWalk:    return .green
        case .cycle:                return .blue
        }
    }

    var isIndoor: Bool { self == .treadmill || self == .indoorWalk }

    var hkType: HKWorkoutActivityType {
        switch self {
        case .run, .treadmill:      return .running
        case .walk, .indoorWalk:    return .walking
        case .cycle:                return .cycling
        }
    }

    /// Maps back to iPhone's CardioType.rawValue
    var payloadRaw: String {
        switch self {
        case .run:        return "Outdoor Run"
        case .treadmill:  return "Indoor Run"
        case .walk:       return "Outdoor Walk"
        case .indoorWalk: return "Indoor Walk"
        case .cycle:      return "Outdoor Cycle"
        }
    }

    static func from(hkType: HKWorkoutActivityType, isIndoor: Bool) -> WatchCardioType {
        switch hkType {
        case .running:  return isIndoor ? .treadmill : .run
        // Now correctly disambiguates the two walk variants — previously
        // every `.walking` collapsed to `.walk` regardless of `isIndoor`,
        // so an indoor-walk session round-tripped as outdoor.
        case .walking:  return isIndoor ? .indoorWalk : .walk
        case .cycling:  return .cycle
        default:        return .run
        }
    }
}
