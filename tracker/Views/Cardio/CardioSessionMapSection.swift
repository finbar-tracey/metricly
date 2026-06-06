import SwiftUI
import MapKit

enum CardioSessionMapSection {
    static func mapCard(session: CardioSession, mapRegion: Binding<MapCameraPosition>) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Route", icon: "map.fill", color: session.type.color)
            let coords = session.routePoints.map(\.coordinate)
            Map(position: mapRegion) {
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
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.tileRadius))
            .onAppear { zoomToRoute(coords, mapRegion: mapRegion) }
        }
        .appCard()
    }

    static func zoomToRoute(_ coords: [CLLocationCoordinate2D], mapRegion: Binding<MapCameraPosition>) {
        guard !coords.isEmpty else { return }
        var minLat = coords[0].latitude, maxLat = coords[0].latitude
        var minLon = coords[0].longitude, maxLon = coords[0].longitude
        for c in coords {
            minLat = min(minLat, c.latitude)
            maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude)
            maxLon = max(maxLon, c.longitude)
        }
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.002, (maxLat - minLat) * 1.3),
            longitudeDelta: max(0.002, (maxLon - minLon) * 1.3)
        )
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        mapRegion.wrappedValue = .region(MKCoordinateRegion(center: center, span: span))
    }
}
