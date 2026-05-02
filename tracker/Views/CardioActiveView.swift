import SwiftUI
import MapKit
import SwiftData

// MARK: - CardioActiveView

struct CardioActiveView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsArray: [UserSettings]
    @Environment(\.weightUnit) private var weightUnit

    let cardioType: CardioType
    let onComplete: (CardioSession) -> Void

    @State private var tracker = CardioTracker.shared
    @State private var showStopAlert = false
    @State private var showSplits = false
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var audioCues = true
    @State private var showSatellite = false
    @State private var countdown = 3
    @State private var countdownActive = true
    @State private var countdownTimer: Timer?
    @State private var completedSession: CardioSession?
    @State private var showCompletion = false

    private var useKm: Bool { settingsArray.first?.useKilograms ?? true }

    var body: some View {
        ZStack(alignment: .bottom) {
            // MARK: Map
            mapLayer

            // MARK: Bottom panel
            VStack(spacing: 0) {
                dragHandle
                statsPanel
                controlsRow
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal, 8)
            .padding(.bottom, 8)

            // Auto-pause badge
            if tracker.state == .paused && !countdownActive {
                VStack {
                    HStack(spacing: 6) {
                        Image(systemName: "pause.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Auto-Paused")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Color.orange.opacity(0.9), in: Capsule())
                    .shadow(radius: 4)
                    .padding(.top, 60)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(), value: tracker.state)
            }

            // MARK: Countdown overlay
            if countdownActive {
                countdownOverlay
            }
        }
        .ignoresSafeArea(edges: .top)
        .statusBar(hidden: true)
        .onAppear {
            if tracker.state == .idle {
                tracker.requestLocationPermission()
                centerOnUser()
                startCountdown()
            }
        }
        .alert("Stop Workout?", isPresented: $showStopAlert) {
            Button("Finish", role: .destructive) { finishSession() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will save your \(cardioType.shortName.lowercased()) and end the session.")
        }
        .fullScreenCover(isPresented: $showCompletion) {
            if let session = completedSession {
                CardioCompletionView(session: session, useKm: useKm) {
                    showCompletion = false
                    dismiss()
                    onComplete(session)
                }
            }
        }
    }

    // MARK: - Countdown overlay

    private var countdownOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 20) {
                Text(countdown > 0 ? "\(countdown)" : "Go!")
                    .font(.system(size: 120, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: countdown)
                Text("Get ready…")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .opacity(countdown > 0 ? 1 : 0)
            }
        }
        .transition(.opacity)
    }

    private func startCountdown() {
        countdown = 3
        countdownActive = true
        countdownTimer?.invalidate()
        var ticks = 0
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            UIImpactFeedbackGenerator(style: ticks < 2 ? .light : .heavy).impactOccurred()
            ticks += 1
            if ticks <= 3 {
                withAnimation { countdown = 3 - ticks }
            }
            if ticks == 3 {
                // "Go!" shown for half a second then dismiss
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(.easeOut(duration: 0.3)) { countdownActive = false }
                    tracker.start(type: cardioType, useKm: useKm, audioCues: audioCues)
                }
                t.invalidate()
            }
        }
        RunLoop.main.add(countdownTimer!, forMode: .common)
    }

    // MARK: - Map Layer

    private var mapLayer: some View {
        Map(position: $cameraPosition) {
            // Route polyline
            if tracker.locations.count > 1 {
                MapPolyline(coordinates: tracker.locations.map(\.coordinate))
                    .stroke(
                        cardioType.color,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                    )
            }
            // User dot
            if let last = tracker.locations.last {
                Annotation("", coordinate: last.coordinate) {
                    ZStack {
                        Circle()
                            .fill(cardioType.color)
                            .frame(width: 18, height: 18)
                        Circle()
                            .stroke(.white, lineWidth: 3)
                            .frame(width: 18, height: 18)
                    }
                    .shadow(color: .black.opacity(0.25), radius: 4)
                }
            }
        }
        .mapStyle(showSatellite ? .imagery(elevation: .realistic) : .standard(elevation: .realistic))
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { showSatellite.toggle() }
            } label: {
                Image(systemName: showSatellite ? "map.fill" : "globe")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 56)
            .padding(.trailing, 16)
        }
        // Keep map centered on user while active
        .onChange(of: tracker.locations.count) {
            if tracker.state == .active, let last = tracker.locations.last {
                withAnimation(.easeOut(duration: 0.3)) {
                    cameraPosition = .camera(
                        MapCamera(centerCoordinate: last.coordinate, distance: 400, heading: 0, pitch: 0)
                    )
                }
            }
        }
    }

    // MARK: - Drag handle

    private var dragHandle: some View {
        Capsule()
            .fill(Color(.tertiaryLabel))
            .frame(width: 40, height: 4)
            .padding(.top, 10)
            .padding(.bottom, 4)
            .onTapGesture { withAnimation(.spring()) { showSplits.toggle() } }
    }

    // MARK: - Stats panel

    private var statsPanel: some View {
        VStack(spacing: 14) {
            // Primary stats
            HStack(spacing: 0) {
                statCell(
                    value: tracker.formattedElapsed,
                    label: "Time",
                    font: .system(size: 38, weight: .black, design: .rounded)
                )
                Divider().frame(height: 50)
                statCell(
                    value: tracker.formattedDistance(useKm: useKm),
                    label: useKm ? "km" : "mi",
                    font: .system(size: 38, weight: .black, design: .rounded)
                )
                Divider().frame(height: 50)
                statCell(
                    value: tracker.formattedCurrentPace(useKm: useKm),
                    label: "Pace " + tracker.paceUnit,
                    font: .system(size: 30, weight: .black, design: .rounded),
                    color: tracker.currentPaceSecPerKm > 0
                        ? PaceZone.zone(for: tracker.currentPaceSecPerKm).color
                        : nil
                )
            }
            .padding(.vertical, 4)

            // Secondary stats row
            HStack(spacing: 20) {
                secondaryStat(
                    icon: "flame.fill",
                    value: String(format: "%.0f", tracker.estimatedCalories()),
                    label: "cal",
                    color: .orange
                )
                secondaryStat(
                    icon: "arrow.up.right",
                    value: String(format: "%.0f m", tracker.elevationGainMeters),
                    label: "Elevation"
                )
                if let hr = tracker.currentHeartRate {
                    secondaryStat(
                        icon: "heart.fill",
                        value: "\(Int(hr)) bpm",
                        label: "Heart Rate",
                        color: .red
                    )
                }
                secondaryStat(
                    icon: "flag.checkered",
                    value: "\(tracker.splits.count)",
                    label: tracker.distanceUnit == "km" ? "km splits" : "mi splits"
                )
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showSplits.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showSplits ? "chevron.down" : "chevron.up")
                            .font(.caption.bold())
                        Text("Splits")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(cardioType.color)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(cardioType.color.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)

            // Splits list (expandable)
            if showSplits && !tracker.splits.isEmpty {
                splitsTable
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.bottom, 8)
    }

    private func statCell(value: String, label: String, font: Font, color: Color? = nil) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(font)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(color.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.primary))
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func secondaryStat(icon: String, value: String, label: String, color: Color = .secondary) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Splits table

    private var splitsTable: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Split").frame(width: 36, alignment: .leading)
                Spacer()
                Text("Time").frame(width: 52, alignment: .trailing)
                Text("Pace").frame(width: 64, alignment: .trailing)
                if tracker.currentHeartRate != nil {
                    Text("HR").frame(width: 40, alignment: .trailing)
                }
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
            .padding(.bottom, 4)

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(tracker.splits.reversed()) { split in
                        HStack {
                            Text("\(split.id)")
                                .font(.caption.bold().monospacedDigit())
                                .frame(width: 36, alignment: .leading)
                            Spacer()
                            Text(split.formattedDuration())
                                .font(.caption.monospacedDigit())
                                .frame(width: 52, alignment: .trailing)
                            Text(split.formattedPace(useKm: useKm))
                                .font(.caption.bold().monospacedDigit())
                                .frame(width: 64, alignment: .trailing)
                            if tracker.currentHeartRate != nil {
                                Text(split.avgHeartRate.map { "\(Int($0))" } ?? "--")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.red)
                                    .frame(width: 40, alignment: .trailing)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 6)
                        Divider().padding(.horizontal, 20)
                    }
                }
            }
            .frame(maxHeight: 180)
        }
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 12)
    }

    // MARK: - Controls

    private var controlsRow: some View {
        HStack(spacing: 28) {
            // Stop button
            Button {
                showStopAlert = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.12))
                        .frame(width: 52, height: 52)
                    Image(systemName: "stop.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.red)
                }
            }
            .buttonStyle(.plain)

            // Manual lap button
            Button {
                tracker.recordManualLap()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 52, height: 52)
                    VStack(spacing: 1) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.blue)
                        Text("Lap")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.blue)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(tracker.state != .active)

            // Pause / Resume — big center button
            Button {
                if tracker.state == .active { tracker.pause() }
                else if tracker.state == .paused { tracker.resume() }
            } label: {
                ZStack {
                    Circle()
                        .fill(cardioType.color)
                        .frame(width: 76, height: 76)
                        .shadow(color: cardioType.color.opacity(0.4), radius: 12, y: 4)
                    Image(systemName: tracker.state == .paused ? "play.fill" : "pause.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: tracker.state)

            // Audio cues toggle
            Button {
                audioCues.toggle()
            } label: {
                ZStack {
                    Circle()
                        .fill(audioCues ? cardioType.color.opacity(0.12) : Color(.tertiarySystemFill))
                        .frame(width: 52, height: 52)
                    Image(systemName: audioCues ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(audioCues ? cardioType.color : .secondary)
                }
            }
            .buttonStyle(.plain)
            .onChange(of: audioCues) { tracker.audioCuesEnabled = audioCues }
        }
        .padding(.vertical, 20)
    }

    // MARK: - Helpers

    private func centerOnUser() {
        cameraPosition = .userLocation(fallback: .automatic)
    }

    private func finishSession() {
        let result = tracker.stop()
        let bodyWeightKg = settingsArray.first.map {
            // Use height/weight from settings if available; else default 70 kg
            $0.useKilograms ? 70.0 : 70.0   // placeholder — tracker uses 70 kg default
        } ?? 70.0

        // Build CardioSession and persist
        let session = CardioSession(
            date: .now,
            title: cardioType.shortName,
            type: cardioType,
            durationSeconds: result.durationSeconds,
            distanceMeters: result.distanceMeters,
            elevationGainMeters: result.elevationGainMeters
        )
        session.avgHeartRate  = result.avgHeartRate
        session.routePoints   = result.locations.map { CardioRoutePoint(location: $0) }
        session.splits        = result.splits
        session.caloriesBurned = tracker.estimatedCalories(bodyWeightKg: bodyWeightKg)

        modelContext.insert(session)
        modelContext.saveOrLog()

        // Save to HealthKit with full distance, calories and HR
        if settingsArray.first?.healthKitEnabled == true {
            Task { try? await HealthKitManager.shared.saveCardioSession(session) }
        }

        tracker.reset()
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        // Push fresh cardio data to home screen widget
        let useKmWidget = settingsArray.first?.useKilograms ?? true
        WidgetDataWriter.update(
            streakDays: 0,
            todayWorkoutName: "",
            weeklyCardioKm: 0,      // CardioHubView will write the full weekly total separately
            lastRunPace: session.formattedPace(useKm: useKmWidget),
            lastRunDist: session.formattedDistance(useKm: useKmWidget),
            weeklyGoal: 0,
            workoutsThisWeek: 0
        )

        // Show completion screen; it will call onComplete when dismissed
        completedSession = session
        showCompletion = true
    }
}
