import SwiftUI
import MapKit
import SwiftData

// MARK: - CardioActiveView

struct CardioActiveView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Environment(\.weightUnit) var weightUnit
    @Environment(\.appServices) private var appServices
    @Query var settingsArray: [UserSettings]
    @Query(sort: \BodyWeightEntry.date, order: .reverse) var bodyWeightEntries: [BodyWeightEntry]
    let cardioType: CardioType
    let onComplete: (CardioSession) -> Void

    @State var tracker = AppServices.shared.cardioTracker
    @State var showStopAlert = false
    @State var showSplits = false
    @State var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State var audioCues = true
    @State var showSatellite = false
    @State var countdown = 3
    @State var countdownActive = true
    @State var countdownTimer: Timer?
    @State var completedSession: CardioSession?
    @State var showCompletion = false

    #if DEBUG
    @State var simulatedHR: Double = 132
    @State var hrSimTimer: Timer?
    #endif

    var useKm: Bool { weightUnit.distanceUnit == .km }

    var displayHeartRate: Double? {
        if let hr = tracker.currentHeartRate { return hr }
        #if DEBUG
        return simulatedHR
        #else
        return nil
        #endif
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            mapLayer

            VStack(spacing: 0) {
                dragHandle
                statsPanel
                controlsRow
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.heroRadius, style: .continuous))
            .padding(.horizontal, 8)
            .padding(.bottom, 8)

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
            #if DEBUG
            startHRSimulation()
            #endif
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

    // MARK: - Helpers

    func centerOnUser() {
        cameraPosition = .userLocation(fallback: .automatic)
    }

    func finishSession() {
        let result = tracker.stop()
        let bodyWeightKg = bodyWeightEntries.first?.weight ?? 70.0

        let session = CardioSession(
            date: result.sessionStart,
            title: cardioType.shortName,
            type: cardioType,
            durationSeconds: result.durationSeconds,
            distanceMeters: result.distanceMeters,
            elevationGainMeters: result.elevationGainMeters
        )
        session.avgHeartRate = result.avgHeartRate
        session.maxHeartRate = result.maxHeartRate
        session.routePoints = result.locations.map { CardioRoutePoint(location: $0) }
        session.splits = result.splits
        session.caloriesBurned = tracker.estimatedCalories(bodyWeightKg: bodyWeightKg)

        modelContext.insert(session)
        modelContext.saveOrLog()

        if settingsArray.first?.healthKitEnabled == true {
            Task {
                do {
                    try await appServices.healthKit.saveCardioSession(session)
                } catch {
                    appServices.appErrorBus.report(message: "Couldn't save cardio to Apple Health.", kind: .warning)
                }
            }
        }

        tracker.reset()
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        let useKmWidget = weightUnit.distanceUnit == .km
        MetriclySyncCoordinator.publishAfterCardioFinishAndRefresh(
            session: session,
            useKm: useKmWidget,
            modelContainer: modelContext.container
        )

        completedSession = session
        showCompletion = true
    }
}
