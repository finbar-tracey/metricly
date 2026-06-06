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
    @Environment(\.appServices) private var appServices
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

    // MARK: - HR effort summary

    private var hrZoneBreakdown: [(zone: HRZone, seconds: Double)] {
        var totals: [HRZone: Double] = [:]
        for split in session.splits {
            guard let hr = split.avgHeartRate else { continue }
            totals[HRZone.zone(for: hr, maxHR: settingsArray.first?.resolvedMaxHR), default: 0] += split.durationSeconds
        }
        let order: [HRZone] = [.easy, .aerobic, .tempo, .threshold, .max]
        return order.compactMap { z in
            let s = totals[z] ?? 0
            return s > 0 ? (zone: z, seconds: s) : nil
        }
    }

    /// Compact "how hard you worked" summary — a stacked zone bar plus the
    /// dominant zone. Shown only when splits carry heart rate.
    @ViewBuilder
    private var hrEffortBar: some View {
        let breakdown = hrZoneBreakdown
        let total = breakdown.reduce(0) { $0 + $1.seconds }
        if total > 0, let dom = breakdown.max(by: { $0.seconds < $1.seconds })?.zone {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill").font(.caption2.bold())
                    Text("Mostly Zone \(dom.number) · \(dom.rawValue)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white.opacity(0.92))
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(breakdown, id: \.zone) { item in
                            Capsule()
                                .fill(item.zone.color)
                                .frame(width: max(4, geo.size.width * CGFloat(item.seconds / total) - 2))
                        }
                    }
                }
                .frame(height: 10)
            }
            .padding(14)
            .background(.ultraThinMaterial.opacity(0.55), in: RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous)
                    .stroke(.white.opacity(0.20), lineWidth: 0.5)
            )
            .padding(.horizontal, 24)
        }
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
                    CardioCompletionHeroSection.content(
                        session: session,
                        useKm: useKm,
                        prs: prs,
                        appeared: appeared,
                        settingsArray: settingsArray,
                        hrEffortBar: { hrEffortBar }
                    )
                    CardioCompletionActionsSection.content(
                        session: session,
                        useKm: useKm,
                        notes: $notes,
                        notesFocused: $notesFocused,
                        appeared: appeared,
                        stravaUpload: stravaUpload,
                        onDone: onDone,
                        stravaStatusPill: { stravaStatusPill }
                    )
                }
            }
        }
        .onAppear {
            appeared = true
            kickOffStravaUploadIfNeeded()
        }
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
              appServices.strava.isConnected,
              session.stravaActivityID == nil
        else { return }

        withAnimation(.easeInOut(duration: 0.3)) {
            stravaUpload = .uploading
        }
        Task {
            do {
                let activity = try await appServices.strava.uploadActivity(session)
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
