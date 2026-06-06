import SwiftUI
import SwiftData

struct CardioHubView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appServices) private var appServices
    @Environment(\.weightUnit) private var weightUnit
    @Query(sort: \CardioSession.date, order: .reverse) private var sessions: [CardioSession]
    @Query private var settingsArray: [UserSettings]

    @State private var showTypePicker = false
    @State private var selectedType: CardioType = .outdoorRun
    @State private var navigateToSession = false
    @State private var route: CardioHubRoute?

    private var useKm: Bool { weightUnit.distanceUnit == .km }

    private var totalDistanceKm: Double {
        sessions.reduce(0) { $0 + $1.distanceMeters } / 1000
    }

    private var thisWeekSessions: [CardioSession] {
        let start = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .distantPast
        return sessions.filter { $0.date >= start }
    }

    private var thisWeekDistanceKm: Double {
        thisWeekSessions.reduce(0) { $0 + $1.distanceMeters } / 1000
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                if !sessions.isEmpty {
                    CardioHubSections.heroCard(
                        totalDistanceKm: totalDistanceKm,
                        sessionCount: sessions.count,
                        thisWeekDistanceKm: thisWeekDistanceKm,
                        useKm: useKm
                    )
                }
                CardioHubSections.startCard(
                    selectedType: $selectedType,
                    onStart: { navigateToSession = true }
                )
                if !sessions.isEmpty {
                    CardioHubSections.personalBestsCard(
                        sessions: sessions,
                        useKm: useKm,
                        onSeeAll: { route = .bests }
                    )
                    CardioHubSections.recentSessionsCard(
                        sessions: sessions,
                        useKm: useKm,
                        onSeeAll: { route = .history }
                    )
                }
                if sessions.isEmpty {
                    CardioHubSections.emptyStateCard(onStart: { navigateToSession = true })
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Cardio")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 2) {
                    Button { route = .bests } label: {
                        Image(systemName: "trophy")
                    }
                    .accessibilityLabel("Personal Bests")
                    Button { route = .goals } label: {
                        Image(systemName: "target")
                    }
                    .accessibilityLabel("Cardio Goals")
                }
            }
        }
        .sheet(isPresented: $showTypePicker) {
            CardioHubSections.typePickerSheet(selectedType: $selectedType, isPresented: $showTypePicker)
        }
        .fullScreenCover(isPresented: $navigateToSession) {
            NavigationStack {
                CardioActiveView(cardioType: selectedType, tracker: appServices.cardioTracker) { session in
                    route = .completed(session.id)
                }
                .toolbar(.hidden, for: .navigationBar)
            }
            .environment(\.weightUnit, weightUnit)
        }
        .navigationDestination(item: $route) { destination in
            switch destination {
            case .history:
                CardioHistoryView()
            case .goals:
                CardioGoalsView()
            case .bests:
                CardioBestsView()
            case .completed(let id):
                if let session = sessions.first(where: { $0.id == id }) {
                    CardioSessionDetailView(session: session)
                } else {
                    ContentUnavailableView("Session Not Found", systemImage: "figure.run")
                }
            }
        }
    }
}
