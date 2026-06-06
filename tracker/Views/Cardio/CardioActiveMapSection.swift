import SwiftUI
import MapKit
import UIKit

extension CardioActiveView {

    // MARK: - Countdown overlay

    var countdownOverlay: some View {
        ZStack {
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

    func startCountdown() {
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

    var mapLayer: some View {
        Map(position: $cameraPosition) {
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
            .accessibilityLabel("Toggle map style")
            .padding(.top, 56)
            .padding(.trailing, 16)
        }
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

    var dragHandle: some View {
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
}
