import SwiftUI
import MapKit
import SwiftData

struct CardioSessionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.weightUnit) private var weightUnit
    @Query private var settingsArray: [UserSettings]
    let session: CardioSession

    @State private var mapRegion: MapCameraPosition = .automatic
    @State private var showDeleteAlert = false
    @State private var shareImage: UIImage? = nil
    @State private var showShare = false
    @State private var stravaUpload: StravaUploadState = .idle
    @StateObject private var stravaService = StravaService.shared

    private var useKm: Bool { weightUnit.distanceUnit == .km }

    /// Only show the status pill when there's something to communicate —
    /// in-flight uploads, success, errors, or "already on Strava". A
    /// connected user with a pristine, never-pushed session sees nothing
    /// because the menu's "Push to Strava" action is the discovery path.
    private var shouldShowStravaPill: Bool {
        if !stravaService.isConnected { return false }
        if session.stravaActivityID != nil { return true }
        switch stravaUpload {
        case .idle: return false
        default:    return true
        }
    }

    @ViewBuilder
    private var stravaStatusPill: some View {
        let tint: Color = {
            switch stravaUpload {
            case .failed:                                    return .red
            case .success, .duplicate:                       return .green
            case .uploading, .idle:
                return session.stravaActivityID != nil ? .green : .orange
            }
        }()

        let icon: String = {
            switch stravaUpload {
            case .uploading:              return "arrow.up.circle"
            case .failed:                 return "exclamationmark.triangle.fill"
            case .success, .duplicate:    return "checkmark.circle.fill"
            case .idle:
                return session.stravaActivityID != nil ? "checkmark.circle.fill" : "figure.run.circle"
            }
        }()

        let title: String = {
            switch stravaUpload {
            case .uploading:        return "Pushing to Strava…"
            case .success:          return "Pushed to Strava"
            case .duplicate:        return "Already on Strava"
            case .failed(let msg):  return "Strava push failed: \(msg)"
            case .idle:
                return session.stravaActivityID != nil ? "Pushed to Strava" : ""
            }
        }()

        HStack(spacing: 10) {
            if case .uploading = stravaUpload {
                ProgressView().tint(tint)
            } else {
                Image(systemName: icon)
                    .foregroundStyle(tint)
            }
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
            if case .failed = stravaUpload {
                Button("Retry") { uploadToStrava() }
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(tint.opacity(0.25), lineWidth: 1)
        )
    }

    private var stravaMenuLabel: String {
        if session.stravaActivityID != nil { return "Already on Strava" }
        switch stravaUpload {
        case .uploading: return "Pushing to Strava…"
        case .failed:    return "Retry push to Strava"
        default:         return "Push to Strava"
        }
    }

    private func uploadToStrava() {
        guard !stravaUpload.isInFlight else { return }
        stravaUpload = .uploading
        Task {
            do {
                let activity = try await StravaService.shared.uploadActivity(session)
                await MainActor.run {
                    session.stravaActivityID = activity.id
                    try? modelContext.save()
                    stravaUpload = .success
                }
            } catch StravaError.duplicateActivity {
                await MainActor.run { stravaUpload = .duplicate }
            } catch {
                await MainActor.run {
                    stravaUpload = .failed(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - HR zones

    /// Time spent in each HR zone, bucketed at split granularity: each
    /// split's duration is assigned to the zone of its average heart rate.
    /// An approximation (not per-second), but honest and useful. Empty when
    /// no split carries a heart rate.
    private var hrZoneBreakdown: [(zone: HRZone, seconds: Double)] {
        var totals: [HRZone: Double] = [:]
        for split in session.splits {
            guard let hr = split.avgHeartRate else { continue }
            totals[HRZone.zone(for: hr), default: 0] += split.durationSeconds
        }
        let order: [HRZone] = [.max, .threshold, .tempo, .aerobic, .easy]
        return order.compactMap { z in
            let s = totals[z] ?? 0
            return s > 0 ? (zone: z, seconds: s) : nil
        }
    }

    private var hrZonesCard: some View {
        let total = hrZoneBreakdown.reduce(0) { $0 + $1.seconds }
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Heart Rate Zones", icon: "heart.fill", color: .red)
            VStack(spacing: 11) {
                ForEach(hrZoneBreakdown, id: \.zone) { item in
                    let pct = total > 0 ? item.seconds / total : 0
                    HStack(spacing: 12) {
                        Text("Z\(item.zone.number)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(item.zone.color)
                            .frame(width: 26, alignment: .leading)
                        Text(item.zone.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 66, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(item.zone.color.opacity(0.16)).frame(height: 8)
                                Capsule().fill(item.zone.color)
                                    .frame(width: max(6, geo.size.width * pct), height: 8)
                            }
                        }
                        .frame(height: 8)
                        Text(formatZoneTime(item.seconds))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 46, alignment: .trailing)
                    }
                }
            }
        }
        .appCard()
    }

    private func formatZoneTime(_ seconds: Double) -> String {
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                heroCard
                if !session.routePoints.isEmpty { mapCard }
                statsCard
                if !hrZoneBreakdown.isEmpty { hrZonesCard }
                if shouldShowStravaPill {
                    stravaStatusPill
                }
                if !session.splits.isEmpty { splitsCard }
                if !session.notes.isEmpty { notesCard }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        shareImage = renderCardioShareImage(session: session, useKm: useKm)
                        showShare = shareImage != nil
                    } label: {
                        Label("Share Run", systemImage: "square.and.arrow.up")
                    }
                    if stravaService.isConnected {
                        Button {
                            uploadToStrava()
                        } label: {
                            Label(stravaMenuLabel, systemImage: "figure.run.circle.fill")
                        }
                        .disabled(stravaUpload.isInFlight || session.stravaActivityID != nil)
                    }
                    Button(role: .destructive) { showDeleteAlert = true } label: {
                        Label("Delete Session", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showShare) {
            if let img = shareImage {
                ShareSheet(items: [img])
                    .presentationDetents([.medium, .large])
            }
        }
        .alert("Delete Session?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                modelContext.delete(session)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [session.type.color, session.type.color.opacity(0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 12) {
                // Type icon + date
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.20))
                            .frame(width: 40, height: 40)
                        Image(systemName: session.type.icon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(session.type.rawValue.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.82))
                            .tracking(0.4)
                        Text(session.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                }

                // Stats — sit on the gradient directly
                HStack(spacing: 0) {
                    HeroStatCol(value: session.formattedDistance(useKm: useKm), label: "Distance")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 28)
                    HeroStatCol(value: session.formattedDuration, label: "Duration")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 28)
                    HeroStatCol(value: session.formattedPace(useKm: useKm), label: "Avg Pace")
                }
            }
            .padding(14)
        }
        .heroCard()
    }


    // MARK: - Map Card

    private var mapCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Route", icon: "map.fill", color: session.type.color)

            let coords = session.routePoints.map(\.coordinate)
            Map(position: $mapRegion) {
                if coords.count > 1 {
                    MapPolyline(coordinates: coords)
                        .stroke(
                            session.type.color,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                        )
                }
                if let start = coords.first {
                    Annotation("Start", coordinate: start) {
                        Circle()
                            .fill(.green)
                            .frame(width: 14, height: 14)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                    }
                }
                if let end = coords.last, coords.count > 1 {
                    Annotation("Finish", coordinate: end) {
                        Circle()
                            .fill(.red)
                            .frame(width: 14, height: 14)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                    }
                }
            }
            .mapStyle(.standard)
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .onAppear { zoomToRoute(coords) }
        }
        .appCard()
    }

    private func zoomToRoute(_ coords: [CLLocationCoordinate2D]) {
        guard !coords.isEmpty else { return }
        var minLat = coords[0].latitude, maxLat = coords[0].latitude
        var minLon = coords[0].longitude, maxLon = coords[0].longitude
        for c in coords {
            minLat = min(minLat, c.latitude);  maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude); maxLon = max(maxLon, c.longitude)
        }
        let span = MKCoordinateSpan(
            latitudeDelta:  max(0.002, (maxLat - minLat) * 1.3),
            longitudeDelta: max(0.002, (maxLon - minLon) * 1.3)
        )
        let center = CLLocationCoordinate2D(
            latitude:  (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        mapRegion = .region(MKCoordinateRegion(center: center, span: span))
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Stats", icon: "chart.bar.fill", color: session.type.color)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                statTile("Distance",    value: session.formattedDistance(useKm: useKm), icon: "ruler",                 color: session.type.color)
                statTile("Duration",    value: session.formattedDuration,               icon: "clock",                 color: .blue)
                statTile("Avg Pace",    value: session.formattedPace(useKm: useKm),    icon: "speedometer",            color: .purple)
                statTile("Splits",      value: "\(session.splits.count)",               icon: "flag.checkered",        color: .orange)
                if session.elevationGainMeters > 0 {
                    statTile("Elevation",   value: String(format: "%.0f m", session.elevationGainMeters), icon: "arrow.up.right", color: .teal)
                }
                if let hr = session.avgHeartRate {
                    statTile("Avg HR",      value: "\(Int(hr)) bpm",                   icon: "heart.fill",            color: .red)
                }
                let cal = session.caloriesBurned ?? session.estimatedCalories()
                if cal > 0 {
                    statTile("Calories",    value: String(format: "%.0f kcal", cal),    icon: "flame.fill",            color: .orange)
                }
            }
        }
        .appCard()
    }

    private func statTile(_ title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.12)).frame(width: 34, height: 34)
                Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.subheadline.bold().monospacedDigit()).lineLimit(1).minimumScaleFactor(0.75)
                Text(title).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Splits Card

    private var splitsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Splits", icon: "flag.checkered", color: session.type.color)

            VStack(spacing: 0) {
                // Header row
                HStack {
                    Text("Split").font(.caption.bold()).frame(width: 40, alignment: .leading)
                    Spacer()
                    Text("Time").font(.caption.bold()).frame(width: 52, alignment: .trailing)
                    Text("Pace").font(.caption.bold()).frame(width: 72, alignment: .trailing)
                    if session.avgHeartRate != nil {
                        Text("HR").font(.caption.bold()).frame(width: 40, alignment: .trailing)
                    }
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                Divider()

                ForEach(session.splits) { split in
                    let paceRaw = useKm ? split.paceSecondsPerKm : split.paceSecondsPerMile
                    let avgPace = useKm ? session.avgPaceSecPerKm : session.avgPaceSecPerMile
                    let isFast = paceRaw < avgPace * 0.97
                    let isSlow = paceRaw > avgPace * 1.03
                    let zone   = PaceZone.zone(for: split.paceSecondsPerKm)

                    HStack {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(zone.color)
                                .frame(width: 7, height: 7)
                            Text("\(split.id)")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .frame(width: 22, alignment: .leading)
                            if isFast {
                                Image(systemName: "arrow.up").font(.system(size: 8, weight: .bold)).foregroundStyle(.green)
                            } else if isSlow {
                                Image(systemName: "arrow.down").font(.system(size: 8, weight: .bold)).foregroundStyle(.orange)
                            }
                        }
                        .frame(width: 48, alignment: .leading)
                        Spacer()
                        Text(split.formattedDuration())
                            .font(.subheadline.monospacedDigit())
                            .frame(width: 52, alignment: .trailing)
                        Text(split.formattedPace(useKm: useKm))
                            .font(.subheadline.bold().monospacedDigit())
                            .foregroundStyle(isFast ? .green : isSlow ? .orange : .primary)
                            .frame(width: 72, alignment: .trailing)
                        if session.avgHeartRate != nil {
                            Text(split.avgHeartRate.map { "\(Int($0))" } ?? "--")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.red)
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    if split.id < session.splits.count { Divider().padding(.horizontal, 16) }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    // MARK: - Notes Card

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Notes", icon: "note.text", color: .secondary)
            Text(session.notes)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }
}
