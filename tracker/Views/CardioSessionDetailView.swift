import SwiftUI
import SwiftData
import MapKit

struct CardioSessionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.weightUnit) private var weightUnit
    @Environment(\.appServices) private var appServices
    @Query private var settingsArray: [UserSettings]

    let session: CardioSession

    @State private var mapRegion: MapCameraPosition = .automatic
    @State private var showDeleteAlert = false
    @State private var shareImage: UIImage?
    @State private var showShare = false
    @State private var stravaUpload: StravaUploadState = .idle

    private var useKm: Bool { weightUnit.distanceUnit == .km }
    private var resolvedMaxHR: Double? { settingsArray.first?.resolvedMaxHR }

    private var hrZoneBreakdown: [(zone: HRZone, seconds: Double)] {
        CardioSessionDetailSections.hrZoneBreakdown(session: session, resolvedMaxHR: resolvedMaxHR)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                CardioSessionDetailSections.heroCard(session: session, useKm: useKm)
                if !session.routePoints.isEmpty {
                    CardioSessionMapSection.mapCard(session: session, mapRegion: $mapRegion)
                }
                CardioSessionDetailSections.statsCard(
                    session: session,
                    useKm: useKm,
                    resolvedMaxHR: resolvedMaxHR
                )
                if !hrZoneBreakdown.isEmpty {
                    CardioSessionDetailSections.hrZonesCard(breakdown: hrZoneBreakdown)
                }
                if CardioSessionActionsSection.shouldShowStravaPill(
                    isConnected: appServices.strava.isConnected,
                    session: session,
                    upload: stravaUpload
                ) {
                    CardioSessionActionsSection.stravaStatusPill(
                        session: session,
                        upload: stravaUpload,
                        onRetry: uploadToStrava
                    )
                }
                if !session.splits.isEmpty {
                    CardioSessionDetailSections.splitsCard(session: session, useKm: useKm)
                }
                if !session.notes.isEmpty {
                    CardioSessionDetailSections.notesCard(notes: session.notes)
                }
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
                    if appServices.strava.isConnected {
                        Button(action: uploadToStrava) {
                            Label(
                                CardioSessionActionsSection.stravaMenuLabel(session: session, upload: stravaUpload),
                                systemImage: "figure.run.circle.fill"
                            )
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

    private func uploadToStrava() {
        CardioSessionActionsSection.uploadToStrava(
            session: session,
            strava: appServices.strava,
            modelContext: modelContext,
            upload: $stravaUpload
        )
    }
}
