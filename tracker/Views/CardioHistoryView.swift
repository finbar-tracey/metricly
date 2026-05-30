import SwiftUI
import SwiftData

struct CardioHistoryView: View {
    @Query(sort: \CardioSession.date, order: .reverse) private var sessions: [CardioSession]
    @Query private var settingsArray: [UserSettings]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.weightUnit) private var weightUnit

    @State private var filterType: CardioType? = nil
    @State private var searchText = ""

    private var distanceUnit: DistanceUnit { weightUnit.distanceUnit }

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
                EmptyStateView(
                    icon: filterType?.icon ?? "figure.run",
                    title: filterType.map { "No \($0.rawValue) Sessions" } ?? "No Sessions",
                    subtitle: filterType == nil ? "Start a session to see it here." : "Try a different filter."
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
                            title: filterType?.rawValue ?? "All Sessions",
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
                colors: AppTheme.Gradients.caution,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            // Top sheen
            LinearGradient(
                colors: [.white.opacity(0.18), .clear],
                startPoint: .top, endPoint: .center
            )
            .blendMode(.plusLighter)
            Circle().fill(.white.opacity(0.10)).frame(width: 150).blur(radius: 10).offset(x: 200, y: -30)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "figure.run")
                        .foregroundStyle(.white.opacity(0.85))
                        .font(.system(size: 13, weight: .bold))
                    Text("All Cardio")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .tracking(0.5)
                        .textCase(.uppercase)
                }
                HStack(spacing: 0) {
                    bannerCol(label: "Sessions",   value: "\(sessions.count)")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 32)
                    bannerCol(label: "Total \(distanceUnit.label)",
                              value: String(format: "%.1f", distanceUnit.display(totalDistanceKm)))
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 32)
                    bannerCol(label: "This Week",  value: "\(thisWeekCount)")
                }
                .padding(.vertical, 10)
                .background(.ultraThinMaterial.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 0.5)
                )
            }
            .padding(18)
        }
        .frame(minHeight: 130)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.heroRadius, style: .continuous))
        .shadow(color: .black.opacity(0.20), radius: 20, y: 8)
    }

    private var thisWeekCount: Int {
        let start = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .distantPast
        return sessions.filter { $0.date >= start }.count
    }

    private func bannerCol(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))
                .tracking(0.4)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Filter Chip

    private func filterChip(label: String, type: CardioType?) -> some View {
        let isActive = filterType == type
        let activeColor = type?.color ?? Color.orange
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) { filterType = type }
        } label: {
            HStack(spacing: 5) {
                if let type { Image(systemName: type.icon).font(.system(size: 11, weight: .bold)) }
                Text(label).font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background {
                if isActive {
                    Capsule().fill(
                        LinearGradient(
                            colors: [activeColor, activeColor.opacity(0.72)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: activeColor.opacity(0.40), radius: 6, y: 3)
                } else {
                    Capsule().fill(Color(.tertiarySystemFill))
                }
            }
            .foregroundStyle(isActive ? .white : .primary)
        }
        .buttonStyle(.pressableCard)
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
                    Text(session.formattedDistance(useKm: distanceUnit == .km))
                        .font(.caption.bold()).foregroundStyle(session.type.color)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(session.formattedDuration).font(.caption.bold().monospacedDigit())
                Text(session.formattedPace(useKm: distanceUnit == .km)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
