import SwiftUI
import SwiftData

struct CardioHistoryView: View {
    @Query(sort: \CardioSession.date, order: .reverse) private var sessions: [CardioSession]
    @Query private var settingsArray: [UserSettings]
    @Environment(\.modelContext) private var modelContext

    @State private var filterType: CardioType? = nil
    @State private var searchText = ""

    private var useKm: Bool { settingsArray.first?.useKilograms ?? true }
    private var distanceUnit: DistanceUnit { useKm ? .km : .mi }

    private var filtered: [CardioSession] {
        var result = sessions
        if let type = filterType { result = result.filter { $0.cardioType == type.rawValue } }
        if !searchText.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }

    private var totalDistanceKm: Double {
        sessions.reduce(0) { $0 + $1.distanceMeters } / 1000
    }

    var body: some View {
        List {
            // Stats banner
            if !sessions.isEmpty {
                Section {
                    statsBanner
                        .listRowBackground(Color.clear)
                        .listRowInsets(.init(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }

            // Filter chips
            if !sessions.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            filterChip(label: "All", type: nil)
                            ForEach(CardioType.allCases) { type in
                                filterChip(label: type.shortName, type: type)
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            }

            // Session list
            if filtered.isEmpty {
                ContentUnavailableView(
                    filterType == nil ? "No Sessions" : "No \(filterType!.rawValue) Sessions",
                    systemImage: filterType?.icon ?? "figure.run",
                    description: Text(filterType == nil ? "Start a session to see it here." : "Try a different filter.")
                )
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(filtered) { session in
                        NavigationLink(destination: CardioSessionDetailView(session: session)) {
                            sessionRow(session)
                        }
                    }
                    .onDelete { offsets in
                        for i in offsets { modelContext.delete(filtered[i]) }
                    }
                } header: {
                    HStack {
                        SectionHeader(
                            title: filterType == nil ? "All Sessions" : filterType!.rawValue,
                            icon: filterType?.icon ?? "list.bullet",
                            color: filterType?.color ?? .orange
                        )
                        Spacer()
                        Text("\(filtered.count)")
                            .font(.caption.bold()).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("All Sessions")
        .searchable(text: $searchText, prompt: "Search sessions")
    }

    // MARK: - Stats Banner

    private var statsBanner: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [.orange, Color(red: 0.85, green: 0.35, blue: 0.1)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Circle().fill(.white.opacity(0.07)).frame(width: 150).offset(x: 200, y: -30)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "figure.run").foregroundStyle(.white.opacity(0.8))
                        .font(.system(size: 12, weight: .semibold))
                    Text("All Cardio").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.8))
                }
                HStack(spacing: 0) {
                    bannerCol(label: "Sessions",   value: "\(sessions.count)")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 28)
                    bannerCol(label: "Total \(distanceUnit.label)",
                              value: String(format: "%.1f", distanceUnit.display(totalDistanceKm)))
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 28)
                    bannerCol(label: "This Week",  value: "\(thisWeekCount)")
                }
            }
            .padding(16)
        }
        .frame(minHeight: 110)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.heroRadius))
    }

    private var thisWeekCount: Int {
        let start = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .distantPast
        return sessions.filter { $0.date >= start }.count
    }

    private func bannerCol(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Filter Chip

    private func filterChip(label: String, type: CardioType?) -> some View {
        let isActive = filterType == type
        return Button {
            withAnimation(.spring(response: 0.3)) { filterType = type }
        } label: {
            HStack(spacing: 4) {
                if let type { Image(systemName: type.icon).font(.system(size: 10)) }
                Text(label).font(.caption.weight(.medium))
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(isActive ? (type?.color ?? Color.orange) : Color(.tertiarySystemFill), in: Capsule())
            .foregroundStyle(isActive ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Session Row

    private func sessionRow(_ session: CardioSession) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(session.type.color.opacity(0.12)).frame(width: 44, height: 44)
                Image(systemName: session.type.icon).font(.system(size: 18)).foregroundStyle(session.type.color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(session.title).font(.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                    Text(session.date, format: .dateTime.month(.abbreviated).day().year())
                        .font(.caption).foregroundStyle(.secondary)
                    Text("·").foregroundStyle(.tertiary)
                    Text(session.formattedDistance(useKm: useKm))
                        .font(.caption.bold()).foregroundStyle(session.type.color)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(session.formattedDuration).font(.caption.bold().monospacedDigit())
                Text(session.formattedPace(useKm: useKm)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
