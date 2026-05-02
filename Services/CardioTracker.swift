import Foundation
import UIKit
import CoreLocation
import CoreMotion
import AVFoundation
import HealthKit
import Observation

// MARK: - CardioTracker

@Observable
final class CardioTracker: NSObject {

    // MARK: - Session state

    enum SessionState: Equatable {
        case idle, active, paused, finished
    }

    var state: SessionState = .idle

    // Live stats (updated on main thread via Timer)
    var elapsedSeconds: Double       = 0
    var distanceMeters: Double       = 0
    var currentPaceSecPerKm: Double  = 0
    var avgPaceSecPerKm: Double      = 0
    var elevationGainMeters: Double  = 0
    var locations: [CLLocation]      = []
    var splits: [CardioSplit]        = []
    var currentHeartRate: Double?    = nil
    var locationAuth: CLAuthorizationStatus = .notDetermined

    // Activity type set at start
    private(set) var currentType: CardioType = .outdoorRun

    // MARK: - Private state

    private var locationManager  = CLLocationManager()
    private var timer: Timer?
    private var sessionStart: Date?
    private var pauseStart: Date?
    private var totalPausedSeconds: Double = 0
    private var lastLocation: CLLocation?
    private var lastAltitude: Double?
    private var splitStartElapsed: Double = 0
    private var splitDistMeters: Double   = 1000   // 1km; caller sets this

    var audioCuesEnabled = true
    private let speechSynth      = AVSpeechSynthesizer()

    // Auto-pause
    var autoPauseEnabled: Bool = true
    private var autoPauseWorkItem: DispatchWorkItem?

    // HealthKit for live heart rate streaming
    private let healthStore = HKHealthStore()
    private var heartRateQuery: HKAnchoredObjectQuery?

    // CoreMotion pedometer for indoor sessions
    private let pedometer = CMPedometer()

    // MARK: - Singleton

    static let shared = CardioTracker()

    override init() {
        super.init()
        locationManager.delegate                    = self
        locationManager.desiredAccuracy             = kCLLocationAccuracyBest
        locationManager.distanceFilter              = 5
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationAuth = locationManager.authorizationStatus
    }

    // MARK: - Authorization

    func requestLocationPermission() {
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
    }

    // MARK: - Session control

    func start(type: CardioType, useKm: Bool, audioCues: Bool) {
        guard state == .idle else { return }

        currentType        = type
        audioCuesEnabled   = audioCues
        splitDistMeters    = useKm ? 1000.0 : 1609.344

        // Reset
        elapsedSeconds      = 0
        distanceMeters      = 0
        currentPaceSecPerKm = 0
        avgPaceSecPerKm     = 0
        elevationGainMeters = 0
        locations           = []
        splits              = []
        lastLocation        = nil
        lastAltitude        = nil
        totalPausedSeconds  = 0
        splitStartElapsed   = 0
        currentHeartRate    = nil

        sessionStart = .now
        state = .active

        if type.usesGPS {
            locationManager.startUpdatingLocation()
        } else {
            startPedometer()
        }

        // 0.5s tick for smooth timer display
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer!, forMode: .common)

        startHeartRateStreaming()
        speakCue("Workout started")
    }

    func pause() {
        guard state == .active else { return }
        state    = .paused
        pauseStart = .now
        autoPauseWorkItem?.cancel(); autoPauseWorkItem = nil
        locationManager.stopUpdatingLocation()
        if !currentType.usesGPS { pedometer.stopUpdates() }
        timer?.invalidate(); timer = nil
        speakCue("Paused. Distance: \(formattedDistanceSpoken(useKm: splitDistMeters < 1500))")
    }

    func resume() {
        guard state == .paused else { return }
        if let ps = pauseStart { totalPausedSeconds += Date.now.timeIntervalSince(ps) }
        pauseStart = nil
        state = .active
        if currentType.usesGPS {
            locationManager.startUpdatingLocation()
        } else {
            startPedometer()
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer!, forMode: .common)
        speakCue("Resumed")
    }

    /// Stop and return captured data for saving
    func stop() -> SessionResult {
        timer?.invalidate(); timer = nil
        locationManager.stopUpdatingLocation()
        pedometer.stopUpdates()
        stopHeartRateStreaming()
        state = .finished

        return SessionResult(
            type:               currentType,
            durationSeconds:    elapsedSeconds,
            distanceMeters:     distanceMeters,
            elevationGainMeters: elevationGainMeters,
            splits:             splits,
            locations:          locations,
            avgHeartRate:       currentHeartRate
        )
    }

    func reset() {
        state = .idle
        elapsedSeconds = 0; distanceMeters = 0
        currentPaceSecPerKm = 0; avgPaceSecPerKm = 0
        locations = []; splits = []
    }

    // MARK: - Tick

    private func tick() {
        guard let start = sessionStart else { return }
        elapsedSeconds = Date.now.timeIntervalSince(start) - totalPausedSeconds
        if distanceMeters > 10 {
            avgPaceSecPerKm = elapsedSeconds / (distanceMeters / 1000)
        }
        checkSplit()
    }

    // MARK: - Manual lap

    func recordManualLap() {
        guard state == .active else { return }
        let splitNumber   = splits.count + 1
        let splitDuration = elapsedSeconds - splitStartElapsed
        let prevCumDist   = splits.last?.cumulativeDistanceMeters ?? 0
        let lapDist       = max(1, distanceMeters - prevCumDist)

        let split = CardioSplit(
            id: splitNumber,
            splitDistanceMeters: lapDist,
            cumulativeDistanceMeters: distanceMeters,
            durationSeconds: splitDuration,
            cumulativeDurationSeconds: elapsedSeconds,
            avgHeartRate: currentHeartRate
        )
        splits.append(split)
        splitStartElapsed = elapsedSeconds

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if audioCuesEnabled { speakCue("Lap \(splitNumber)") }
    }

    // MARK: - Splits

    private func checkSplit() {
        let completedSplits = Int(distanceMeters / splitDistMeters)
        guard completedSplits > splits.count else { return }

        let splitNumber   = splits.count + 1
        let splitDuration = elapsedSeconds - splitStartElapsed
        let cumDist       = Double(splitNumber) * splitDistMeters

        let split = CardioSplit(
            id: splitNumber,
            splitDistanceMeters: splitDistMeters,
            cumulativeDistanceMeters: cumDist,
            durationSeconds: splitDuration,
            cumulativeDurationSeconds: elapsedSeconds,
            avgHeartRate: currentHeartRate
        )
        splits.append(split)
        splitStartElapsed = elapsedSeconds

        if audioCuesEnabled { announceSplit(split) }
    }

    // MARK: - Audio cues

    private func speakCue(_ text: String) {
        guard audioCuesEnabled else { return }
        let utt = AVSpeechUtterance(string: text)
        utt.voice = AVSpeechSynthesisVoice(language: "en-US")
        utt.rate  = AVSpeechUtteranceDefaultSpeechRate
        speechSynth.speak(utt)
    }

    private func announceSplit(_ split: CardioSplit) {
        let useKm = splitDistMeters < 1500
        let unit  = useKm ? "kilometre" : "mile"
        let pace  = useKm ? split.paceSecondsPerKm : split.paceSecondsPerMile
        let pMin  = Int(pace) / 60; let pSec = Int(pace) % 60
        let unitLabel = useKm ? "kilometre" : "mile"
        speakCue("\(split.id) \(unit). Pace \(pMin) \(pSec == 0 ? "" : "minutes \(pSec) seconds") per \(unitLabel).")
    }

    private func formattedDistanceSpoken(useKm: Bool) -> String {
        if useKm {
            return String(format: "%.1f kilometres", distanceMeters / 1000)
        } else {
            return String(format: "%.1f miles", distanceMeters / 1609.344)
        }
    }

    // MARK: - Pedometer (indoor sessions)

    private func startPedometer() {
        guard CMPedometer.isDistanceAvailable() else { return }
        let from = sessionStart ?? .now
        pedometer.startUpdates(from: from) { [weak self] data, _ in
            guard let self, let data, state == .active else { return }
            let meters = data.distance?.doubleValue ?? 0
            DispatchQueue.main.async {
                self.distanceMeters = meters
                if self.elapsedSeconds > 0 && meters > 0 {
                    let paceRaw = self.elapsedSeconds / (meters / 1000)
                    self.currentPaceSecPerKm = paceRaw
                }
            }
        }
    }

    // MARK: - HealthKit heart rate streaming

    private func startHeartRateStreaming() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }

        let query = HKAnchoredObjectQuery(
            type: hrType,
            predicate: HKQuery.predicateForSamples(
                withStart: sessionStart ?? .now,
                end: nil,
                options: .strictStartDate
            ),
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.processHRSamples(samples)
        }
        query.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.processHRSamples(samples)
        }
        healthStore.execute(query)
        heartRateQuery = query
    }

    private func stopHeartRateStreaming() {
        if let q = heartRateQuery { healthStore.stop(q) }
        heartRateQuery = nil
    }

    private func processHRSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], let last = samples.last else { return }
        let bpm = last.quantity.doubleValue(for: HKUnit(from: "count/min"))
        DispatchQueue.main.async { self.currentHeartRate = bpm }
    }

    // MARK: - Formatted helpers (for UI binding)

    var formattedElapsed: String {
        let h = Int(elapsedSeconds) / 3600
        let m = Int(elapsedSeconds) % 3600 / 60
        let s = Int(elapsedSeconds) % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    func formattedCurrentPace(useKm: Bool) -> String {
        let pace = useKm ? currentPaceSecPerKm : currentPaceSecPerKm * 1.609344
        guard pace > 0 && pace < 1800 else { return "--:--" }
        return String(format: "%d:%02d", Int(pace) / 60, Int(pace) % 60)
    }

    func formattedDistance(useKm: Bool) -> String {
        useKm
            ? String(format: "%.2f", distanceMeters / 1000)
            : String(format: "%.2f", distanceMeters / 1609.344)
    }

    var distanceUnit: String { splitDistMeters < 1500 ? "km" : "mi" }
    var paceUnit: String { splitDistMeters < 1500 ? "/km" : "/mi" }

    /// Estimate calories burned. Pass body weight in kg (default 70 if unknown).
    func estimatedCalories(bodyWeightKg: Double = 70) -> Double {
        // MET (Metabolic Equivalent of Task) values
        let met: Double
        switch currentType {
        case .outdoorRun, .indoorRun:   met = 9.8
        case .outdoorWalk, .indoorWalk: met = 3.5
        case .outdoorCycle:             met = 7.5
        }
        return met * bodyWeightKg * (elapsedSeconds / 3600)
    }
}

// MARK: - CLLocationManagerDelegate

extension CardioTracker: CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        locationAuth = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedWhenInUse {
            // Ready
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations newLocations: [CLLocation]) {
        guard state == .active else { return }
        for loc in newLocations {
            guard loc.horizontalAccuracy >= 0 && loc.horizontalAccuracy < 50 else { continue }

            // Auto-pause: if speed is available and below 0.5 m/s (~1.8 km/h) for 4 s, pause
            if autoPauseEnabled && currentType.usesGPS {
                let spd = loc.speed   // -1 if unavailable
                if spd >= 0 && spd < 0.5 {
                    if autoPauseWorkItem == nil {
                        let work = DispatchWorkItem { [weak self] in
                            guard let self, state == .active else { return }
                            pause()
                            speakCue("Auto paused")
                            autoPauseWorkItem = nil
                        }
                        autoPauseWorkItem = work
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: work)
                    }
                } else {
                    // Moving — cancel pending auto-pause
                    autoPauseWorkItem?.cancel()
                    autoPauseWorkItem = nil
                    // Auto-resume if we were auto-paused
                    if state == .paused { resume() }
                }
            }

            if let last = lastLocation {
                let delta = loc.distance(from: last)
                if delta >= 1 {
                    distanceMeters += delta
                    // Elevation gain
                    if let prevAlt = lastAltitude, loc.altitude > prevAlt + 0.5 {
                        elevationGainMeters += loc.altitude - prevAlt
                    }
                    // Smoothed live pace
                    let dt = loc.timestamp.timeIntervalSince(last.timestamp)
                    if dt > 0 && delta > 2 {
                        let rawPace = dt / (delta / 1000)
                        currentPaceSecPerKm = currentPaceSecPerKm == 0
                            ? rawPace
                            : currentPaceSecPerKm * 0.75 + rawPace * 0.25
                    }
                }
            }
            lastAltitude = loc.altitude
            lastLocation = loc
            locations.append(loc)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // GPS temporarily unavailable — continue silently
    }
}

// MARK: - SessionResult (returned by stop())

struct SessionResult {
    let type: CardioType
    let durationSeconds: Double
    let distanceMeters: Double
    let elevationGainMeters: Double
    let splits: [CardioSplit]
    let locations: [CLLocation]
    let avgHeartRate: Double?
}
