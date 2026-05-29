import SwiftUI
import MapKit
import SwiftData

// MARK: - CardioActiveView

struct CardioActiveView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsArray: [UserSettings]
    @Query(sort: \BodyWeightEntry.date, order: .reverse) private var bodyWeightEntries: [BodyWeightEntry]
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

    private var useKm: Bool { weightUnit.distanceUnit == .km }

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
            // Layered background: dim + radial color glow
            Color.black.opacity(0.62).ignoresSafeArea()
            RadialGradient(
                colors: [cardioType.color.opacity(0.35), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 280
            )
            .ignoresSafeArea()
            VStack(spacing: 22) {
                Text(countdown > 0 ? "\(countdown)" : "Go!")
                    .font(.system(size: 130, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.32, dampingFraction: 0.6), value: countdown)
                    .shadow(color: cardioType.color.opacity(0.55), radius: 22, y: 6)
                Text(countdown > 0 ? "GET READY" : "")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .tracking(1.0)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(.ultraThinMaterial.opacity(0.7), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 0.5))
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
            // Route polyline — gradient stroke with soft shadow halo (rendered as a wider faded underlay)
            if tracker.locations.count > 1 {
                MapPolyline(coordinates: tracker.locations.map(\.coordinate))
                    .stroke(
                        cardioType.color.opacity(0.30),
                        style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round)
                    )
                MapPolyline(coordinates: tracker.locations.map(\.coordinate))
                    .stroke(
                        LinearGradient(
                            colors: [cardioType.color, cardioType.color.opacity(0.78)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
                    )
            }
            // User dot
            if let last = tracker.locations.last {
                Annotation("", coordinate: last.coordinate) {
                    ZStack {
                        Circle()
                            .fill(cardioType.color.opacity(0.25))
                            .frame(width: 34, height: 34)
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [cardioType.color, cardioType.color.opacity(0.75)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 20, height: 20)
                        Circle()
                            .stroke(.white, lineWidth: 3)
                            .frame(width: 20, height: 20)
                    }
                    .shadow(color: cardioType.color.opacity(0.55), radius: 6)
                    .shadow(color: .black.opacity(0.30), radius: 4, y: 1)
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
            .fill(
                LinearGradient(
                    colors: [Color(.tertiaryLabel), Color(.tertiaryLabel).opacity(0.5)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 44, height: 5)
            .padding(.top, 11)
            .padding(.bottom, 4)
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) { showSplits.toggle() }
            }
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
                    label: useKm ? "km splits" : "mi splits"
                )
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                        showSplits.toggle()
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: showSplits ? "chevron.down" : "chevron.up")
                            .font(.caption.bold())
                        Text("Splits")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(cardioType.color)
                    .padding(.horizontal, 11).padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [cardioType.color.opacity(0.18), cardioType.color.opacity(0.10)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Capsule()
                    )
                    .overlay(Capsule().stroke(cardioType.color.opacity(0.22), lineWidth: 0.5))
                }
                .buttonStyle(.pressableCard)
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
        VStack(spacing: 4) {
            Text(value)
                .font(font)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(color.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.primary))
                .contentTransition(.numericText())
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(0.4)
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
                Text("SPLIT").frame(width: 40, alignment: .leading)
                Spacer()
                Text("TIME").frame(width: 56, alignment: .trailing)
                Text("PACE").frame(width: 68, alignment: .trailing)
                if tracker.currentHeartRate != nil {
                    Text("HR").frame(width: 42, alignment: .trailing)
                }
            }
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(0.5)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 6)

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(tracker.splits.reversed()) { split in
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(cardioType.color.opacity(0.16))
                                    .frame(width: 28, height: 28)
                                Text("\(split.id)")
                                    .font(.system(size: 12, weight: .black, design: .rounded).monospacedDigit())
                                    .foregroundStyle(cardioType.color)
                            }
                            .frame(width: 40, alignment: .leading)
                            Spacer()
                            Text(split.formattedDuration())
                                .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                                .frame(width: 56, alignment: .trailing)
                            Text(split.formattedPace(useKm: useKm))
                                .font(.system(size: 13, weight: .black, design: .rounded).monospacedDigit())
                                .foregroundStyle(cardioType.color)
                                .frame(width: 68, alignment: .trailing)
                            if tracker.currentHeartRate != nil {
                                Text(split.avgHeartRate.map { "\(Int($0))" } ?? "--")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                                    .foregroundStyle(.red)
                                    .frame(width: 42, alignment: .trailing)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        Divider().padding(.horizontal, 20)
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
        .padding(.horizontal, 12)
    }

    // MARK: - Controls

    private var controlsRow: some View {
        HStack(spacing: 28) {
            // Stop button
            Button {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                showStopAlert = true
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.red.opacity(0.20), Color.red.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .overlay(Circle().stroke(Color.red.opacity(0.30), lineWidth: 1))
                    Image(systemName: "stop.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.red)
                }
            }
            .buttonStyle(.pressableCard)

            // Manual lap button
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                tracker.recordManualLap()
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.20), Color.blue.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .overlay(Circle().stroke(Color.blue.opacity(0.30), lineWidth: 1))
                    VStack(spacing: 1) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.blue)
                        Text("LAP")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(0.5)
                            .foregroundStyle(.blue)
                    }
                }
            }
            .buttonStyle(.pressableCard)
            .disabled(tracker.state != .active)
            .opacity(tracker.state == .active ? 1 : 0.45)

            // Pause / Resume — big center button
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                if tracker.state == .active { tracker.pause() }
                else if tracker.state == .paused { tracker.resume() }
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [cardioType.color, cardioType.color.opacity(0.78)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 84, height: 84)
                        .shadow(color: cardioType.color.opacity(0.50), radius: 14, y: 5)
                        .overlay(Circle().stroke(.white.opacity(0.20), lineWidth: 0.5))
                    Image(systemName: tracker.state == .paused ? "play.fill" : "pause.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .buttonStyle(.pressableCard)
            .animation(.spring(response: 0.42, dampingFraction: 0.78), value: tracker.state)

            // Audio cues toggle
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                audioCues.toggle()
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            audioCues
                                ? AnyShapeStyle(LinearGradient(
                                    colors: [cardioType.color.opacity(0.20), cardioType.color.opacity(0.10)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                : AnyShapeStyle(Color(.tertiarySystemFill))
                        )
                        .frame(width: 56, height: 56)
                        .overlay(
                            Circle().stroke(audioCues ? cardioType.color.opacity(0.30) : Color.clear, lineWidth: 1)
                        )
                    Image(systemName: audioCues ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(audioCues ? cardioType.color : .secondary)
                }
            }
            .buttonStyle(.pressableCard)
            .onChange(of: audioCues) { tracker.audioCuesEnabled = audioCues }
        }
        .padding(.vertical, 22)
    }

    // MARK: - Helpers

    private func centerOnUser() {
        cameraPosition = .userLocation(fallback: .automatic)
    }

    private func finishSession() {
        let result = tracker.stop()
        // Use latest logged body weight; fall back to 70 kg if none recorded yet
        let bodyWeightKg = bodyWeightEntries.first?.weight ?? 70.0

        // Build CardioSession and persist. Pass the actual session start
        // (from `CardioTracker.sessionStart`) instead of `.now` — the
        // legacy `date: .now` populated the field with finish time and
        // was the root of the v1.5-review timestamp bug (Strava upload
        // sent finish time as start, HealthKit shifted everything back
        // by duration). The new init writes start/end explicitly.
        let session = CardioSession(
            date: result.sessionStart,
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
            Task {
                do {
                    try await HealthKitManager.shared.saveCardioSession(session)
                } catch {
                    AppErrorBus.shared.report(message: "Couldn't save cardio to Apple Health.", kind: .warning)
                }
            }
        }

        tracker.reset()
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        // Push fresh cardio data to home screen widget — only what we know.
        // Streak / weekly cardio km are recomputed by ContentView's full update.
        let useKmWidget = weightUnit.distanceUnit == .km
        WidgetDataWriter.update(
            lastRunPace: session.formattedPace(useKm: useKmWidget),
            lastRunDist: session.formattedDistance(useKm: useKmWidget)
        )

        // Show completion screen; it will call onComplete when dismissed
        completedSession = session
        showCompletion = true
    }
}
