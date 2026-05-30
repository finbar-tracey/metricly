import SwiftUI
import SwiftData

// MARK: - Cardio PRs

struct CardioPR: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let value: String
    let color: Color
}

/// Compute which PRs this session broke vs all previous sessions.
func cardioSessionPRs(session: CardioSession, allSessions: [CardioSession], useKm: Bool) -> [CardioPR] {
    // Only consider sessions that aren't this one
    let others = allSessions.filter { $0.id != session.id }
    var prs: [CardioPR] = []

    // 1. Longest distance
    let prevMaxDist = others.map(\.distanceMeters).max() ?? 0
    if session.distanceMeters > prevMaxDist && session.distanceMeters > 100 {
        prs.append(CardioPR(
            icon: "ruler",
            label: "Longest \(session.type.shortName)",
            value: session.formattedDistance(useKm: useKm),
            color: session.type.color
        ))
    }

    // 2. Fastest average pace (lower = better)
    let prevFastestPace = others
        .filter { $0.distanceMeters > 500 }
        .map { $0.avgPaceSecPerKm }
        .filter { $0 > 0 }
        .min() ?? .greatestFiniteMagnitude
    if session.avgPaceSecPerKm > 0 && session.distanceMeters > 500 && session.avgPaceSecPerKm < prevFastestPace {
        prs.append(CardioPR(
            icon: "speedometer",
            label: "Fastest Avg Pace",
            value: session.formattedPace(useKm: useKm),
            color: .purple
        ))
    }

    // 3. Fastest km/mi split
    let sessionFastestSplit = session.splits.map { useKm ? $0.paceSecondsPerKm : $0.paceSecondsPerMile }.filter { $0 > 0 }.min() ?? .greatestFiniteMagnitude
    let prevFastestSplit = others.flatMap(\.splits).map { useKm ? $0.paceSecondsPerKm : $0.paceSecondsPerMile }.filter { $0 > 0 }.min() ?? .greatestFiniteMagnitude
    if sessionFastestSplit < prevFastestSplit && sessionFastestSplit < .greatestFiniteMagnitude {
        let min = Int(sessionFastestSplit) / 60; let sec = Int(sessionFastestSplit) % 60
        prs.append(CardioPR(
            icon: "flag.checkered",
            label: useKm ? "Fastest km Split" : "Fastest mi Split",
            value: String(format: "%d:%02d / %@", min, sec, useKm ? "km" : "mi"),
            color: .green
        ))
    }

    return prs
}

// MARK: - CardioCompletionView

struct CardioCompletionView: View {
    @Query(sort: \CardioSession.date, order: .reverse) private var allSessions: [CardioSession]
    @Query private var settingsArray: [UserSettings]

    let session: CardioSession
    let useKm: Bool
    let onDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var appeared = false
    @State private var notes = ""
    @FocusState private var notesFocused: Bool

    /// Auto-share preference from Settings. Read via @AppStorage so we
    /// don't need a SwiftData fetch on the finish hot path.
    @AppStorage("strava.autoShareCardio") private var autoShareCardio: Bool = true

    /// Local upload state for THIS completion screen. Drives a small
    /// status pill that fades in once an upload kicks off.
    @State private var stravaUpload: StravaUploadState = .idle

    private var prs: [CardioPR] {
        cardioSessionPRs(session: session, allSessions: allSessions, useKm: useKm)
    }

    var body: some View {
        ZStack {
            // Background gradient matching activity type
            LinearGradient(
                colors: [
                    session.type.color,
                    session.type.color.opacity(0.78),
                    session.type.color.opacity(0.55)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            // Top sheen
            LinearGradient(
                colors: [.white.opacity(0.18), .clear],
                startPoint: .top, endPoint: .center
            )
            .blendMode(.plusLighter)
            .ignoresSafeArea()

            Circle().fill(.white.opacity(0.10)).frame(width: 300).blur(radius: 18).offset(x: 130, y: -200)
            Circle().fill(.white.opacity(0.06)).frame(width: 180).blur(radius: 14).offset(x: -80, y: 250)

            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 60)

                    // Trophy / icon
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial.opacity(0.7))
                            .frame(width: 116, height: 116)
                            .overlay(Circle().stroke(.white.opacity(0.30), lineWidth: 0.8))
                        Circle()
                            .fill(.white.opacity(0.18))
                            .frame(width: 86, height: 86)
                        Image(systemName: prs.isEmpty ? "checkmark.circle.fill" : "trophy.fill")
                            .font(.system(size: 50, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                    }
                    .scaleEffect(appeared ? 1 : 0.4)
                    .animation(.spring(response: 0.55, dampingFraction: 0.65).delay(0.1), value: appeared)

                    // Headline
                    VStack(spacing: 8) {
                        Text(prs.isEmpty ? "Session Complete!" : "New Record!")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)
                        Text(session.date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.25), value: appeared)

                    // Key stats strip
                    HStack(spacing: 0) {
                        completionStat(label: "Distance", value: session.formattedDistance(useKm: useKm))
                        Rectangle().fill(.white.opacity(0.3)).frame(width: 1, height: 40)
                        completionStat(label: "Duration", value: session.formattedDuration)
                        Rectangle().fill(.white.opacity(0.3)).frame(width: 1, height: 40)
                        completionStat(label: "Avg Pace", value: session.formattedPace(useKm: useKm))
                    }
                    .padding(.vertical, 16)
                    .background(.ultraThinMaterial.opacity(0.6), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(.white.opacity(0.20), lineWidth: 0.5)
                    )
                    .padding(.horizontal, 24)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.35), value: appeared)

                    // Calories + splits row
                    HStack(spacing: 12) {
                        let cal = session.caloriesBurned ?? session.estimatedCalories()
                        if cal > 0 {
                            miniStat(icon: "flame.fill", value: String(format: "%.0f", cal), label: "kcal", color: .orange)
                        }
                        miniStat(icon: "flag.checkered", value: "\(session.splits.count)", label: "splits", color: .white.opacity(0.8))
                        if session.elevationGainMeters > 1 {
                            miniStat(icon: "arrow.up.right", value: String(format: "%.0f m", session.elevationGainMeters), label: "gain", color: .white.opacity(0.8))
                        }
                        if let hr = session.avgHeartRate {
                            // Surface the average-effort HR zone, mirroring the
                            // live zone ring on the active session.
                            let zone = HRZone.zone(for: hr)
                            miniStat(icon: "heart.fill", value: "\(Int(hr))",
                                     label: "Z\(zone.number) · \(zone.rawValue)", color: zone.color)
                        }
                    }
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.4), value: appeared)

                    // Strava status pill — only shown when an upload is in
                    // flight or has completed. Idle state stays invisible
                    // so users who don't have Strava connected see no
                    // residue of the integration.
                    if stravaUpload != .idle {
                        stravaStatusPill
                            .padding(.horizontal, 24)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // PRs section
                    if !prs.isEmpty {
                        VStack(spacing: 10) {
                            ForEach(prs) { pr in
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(.ultraThinMaterial.opacity(0.7))
                                            .frame(width: 44, height: 44)
                                            .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.5))
                                        Image(systemName: pr.icon)
                                            .font(.system(size: 17, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(pr.label.uppercased())
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                            .tracking(0.4)
                                            .foregroundStyle(.white.opacity(0.78))
                                        Text(pr.value)
                                            .font(.system(size: 16, weight: .black, design: .rounded))
                                            .foregroundStyle(.white)
                                    }
                                    Spacer()
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(.yellow)
                                        .font(.system(size: 16, weight: .bold))
                                        .shadow(color: .yellow.opacity(0.5), radius: 4)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 12)
                                .background(.ultraThinMaterial.opacity(0.55), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(.white.opacity(0.20), lineWidth: 0.5)
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.5), value: appeared)
                    }

                    // Notes field
                    VStack(alignment: .leading, spacing: 8) {
                        Label {
                            Text("Add a note")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .tracking(0.5)
                                .textCase(.uppercase)
                        } icon: {
                            Image(systemName: "note.text").font(.caption.bold())
                        }
                        .foregroundStyle(.white.opacity(0.78))
                        TextField("How did it feel?", text: $notes, axis: .vertical)
                            .lineLimit(2...4)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .tint(.white)
                            .focused($notesFocused)
                            .padding(14)
                            .background(.ultraThinMaterial.opacity(0.55), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(.white.opacity(0.20), lineWidth: 0.5)
                            )
                    }
                    .padding(.horizontal, 24)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.52), value: appeared)

                    Spacer(minLength: 16)

                    // Action buttons
                    VStack(spacing: 12) {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            session.notes = notes
                            onDone()
                        } label: {
                            Text("View Full Report")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 17)
                                .background(.white)
                                .foregroundStyle(session.type.color)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .shadow(color: .black.opacity(0.20), radius: 10, y: 5)
                        }
                        .buttonStyle(.pressableCard)

                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            let img = renderCardioShareImage(session: session, useKm: useKm)
                            guard let img else { return }
                            let av = UIActivityViewController(activityItems: [img], applicationActivities: nil)
                            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let root = scene.windows.first?.rootViewController {
                                root.present(av, animated: true)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Run")
                            }
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(.ultraThinMaterial.opacity(0.65), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(.white.opacity(0.22), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.pressableCard)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.55), value: appeared)
                }
            }
        }
        .onAppear {
            appeared = true
            kickOffStravaUploadIfNeeded()
        }
    }

    private func completionStat(label: String, value: String) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.5)
                .foregroundStyle(.white.opacity(0.78))
        }
        .frame(maxWidth: .infinity)
    }

    private func miniStat(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.5)
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(.horizontal, 13).padding(.vertical, 9)
        .background(.ultraThinMaterial.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.20), lineWidth: 0.5)
        )
    }

    // MARK: - Strava

    /// Kicks off the auto-share upload when:
    /// 1. The user has enabled auto-share in Settings.
    /// 2. They've connected their Strava account.
    /// 3. This session hasn't already been pushed (no stravaActivityID).
    ///
    /// The Task is deliberately unowned by the view's lifecycle so the
    /// upload completes even if the user dismisses the completion screen
    /// before the API call returns. We write the resulting activity ID
    /// straight to the persisted model so future visits to this session
    /// see "Pushed to Strava" without re-asking the API.
    private func kickOffStravaUploadIfNeeded() {
        guard autoShareCardio,
              StravaService.shared.isConnected,
              session.stravaActivityID == nil
        else { return }

        withAnimation(.easeInOut(duration: 0.3)) {
            stravaUpload = .uploading
        }
        Task {
            do {
                let activity = try await StravaService.shared.uploadActivity(session)
                await MainActor.run {
                    session.stravaActivityID = activity.id
                    try? modelContext.save()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        stravaUpload = .success
                    }
                }
            } catch StravaError.duplicateActivity {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        stravaUpload = .duplicate
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        stravaUpload = .failed(error.localizedDescription)
                    }
                }
            }
        }
    }

    /// Compact pill that lives between the stats strip and the PR list.
    /// Glass-style background to match the celebration theme.
    @ViewBuilder
    private var stravaStatusPill: some View {
        let (icon, title, useSpinner): (String, String, Bool) = {
            switch stravaUpload {
            case .uploading:
                return ("arrow.up.circle", "Pushing to Strava…", true)
            case .success:
                return ("checkmark.circle.fill", "Pushed to Strava", false)
            case .duplicate:
                return ("checkmark.circle.fill", "Already on Strava", false)
            case .failed:
                return ("exclamationmark.triangle.fill",
                        "Strava push failed — tap retry in Settings", false)
            case .idle:
                return ("", "", false)
            }
        }()

        HStack(spacing: 10) {
            if useSpinner {
                ProgressView().tint(.white)
            } else {
                Image(systemName: icon)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
            }
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            .ultraThinMaterial.opacity(0.55),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.20), lineWidth: 0.5)
        )
    }
}
