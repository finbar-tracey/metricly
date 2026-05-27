import SwiftUI
import SwiftData

struct CardioHubView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.weightUnit) private var weightUnit
    @Query(sort: \CardioSession.date, order: .reverse) private var sessions: [CardioSession]
    @Query private var settingsArray: [UserSettings]

    @State private var showTypePicker = false
    @State private var selectedType: CardioType = .outdoorRun
    @State private var navigateToSession = false
    @State private var showHistory = false
    @State private var showGoals = false
    @State private var showBests = false
    @State private var completedSession: CardioSession? = nil
    @State private var showCompletedDetail = false

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
                if !sessions.isEmpty { heroCard }
                startCard
                if !sessions.isEmpty { personalBestsCard }
                if !sessions.isEmpty { recentSessionsCard }
                if sessions.isEmpty { emptyStateCard }
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
                    Button { showBests = true } label: {
                        Image(systemName: "trophy")
                    }
                    .accessibilityLabel("Personal Bests")
                    Button { showGoals = true } label: {
                        Image(systemName: "target")
                    }
                    .accessibilityLabel("Cardio Goals")
                }
            }
        }
        // Type picker sheet
        .sheet(isPresented: $showTypePicker) {
            typePickerSheet
        }
        // Navigate to active session (presented as full-screen cover)
        .fullScreenCover(isPresented: $navigateToSession) {
            NavigationStack {
                CardioActiveView(cardioType: selectedType) { session in
                    completedSession = session
                    showCompletedDetail = true
                }
                .toolbar(.hidden, for: .navigationBar)
            }
            .environment(\.weightUnit, weightUnit)
        }
        // After session completes, navigate to its detail view
        .navigationDestination(isPresented: $showCompletedDetail) {
            if let session = completedSession {
                CardioSessionDetailView(session: session)
            }
        }
        // Full history
        .navigationDestination(isPresented: $showHistory) {
            CardioHistoryView()
        }
        // Goals
        .navigationDestination(isPresented: $showGoals) {
            CardioGoalsView()
        }
        // Personal Bests
        .navigationDestination(isPresented: $showBests) {
            CardioBestsView()
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        HeroCard(palette: AppTheme.Gradients.caution) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 6) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("Cardio")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .tracking(0.6)
                        .textCase(.uppercase)
                }

                let distUnit: DistanceUnit = useKm ? .km : .mi
                HStack(spacing: 0) {
                    HeroStatCol(
                        value: String(format: "%.1f %@", distUnit.display(totalDistanceKm), distUnit.label),
                        label: "All Time"
                    )
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 36)
                    HeroStatCol(value: "\(sessions.count)", label: "Sessions")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 36)
                    HeroStatCol(
                        value: String(format: "%.1f %@", distUnit.display(thisWeekDistanceKm), distUnit.label),
                        label: "This Week"
                    )
                }
                .padding(.vertical, 12)
                .background(.ultraThinMaterial.opacity(0.55), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 0.5)
                )
            }
            .padding(20)
        }
        .frame(minHeight: 145)
    }

    // MARK: - Start Card

    private var startCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Start Activity", icon: "play.circle.fill", color: .orange)

            // Activity type selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(CardioType.allCases) { type in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedType = type
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: type.icon)
                                    .font(.system(size: 13, weight: .bold))
                                Text(type.rawValue)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(selectedType == type ? .white : .primary)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background {
                                if selectedType == type {
                                    Capsule().fill(
                                        LinearGradient(
                                            colors: [type.color, type.color.opacity(0.72)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: type.color.opacity(0.45), radius: 8, y: 3)
                                } else {
                                    Capsule().fill(Color(.tertiarySystemGroupedBackground))
                                }
                            }
                        }
                        .buttonStyle(.pressableCard)
                        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: selectedType)
                    }
                }
                .padding(.horizontal, 2)
            }

            // Start button
            Button {
                navigateToSession = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: selectedType.icon)
                        .font(.system(size: 18, weight: .semibold))
                    Text("Start \(selectedType.rawValue)")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(colors: [selectedType.color, selectedType.color.opacity(0.75)],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: selectedType.color.opacity(0.35), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
        }
        .appCard()
    }

    // MARK: - Personal Bests Card

    private var personalBestsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "Personal Bests", icon: "trophy.fill", color: .yellow)
                Spacer()
                Button { showBests = true } label: {
                    Text("See All").font(.caption.weight(.semibold)).foregroundStyle(.orange)
                }
            }

            // Quick preview: 5K and fastest pace
            let runSessions = sessions.filter { $0.cardioType == CardioType.outdoorRun.rawValue || $0.cardioType == CardioType.indoorRun.rawValue }
            let best5k = runSessions
                .filter { $0.distanceMeters >= 4750 && $0.avgPaceSecPerKm > 0 }
                .min(by: { $0.avgPaceSecPerKm < $1.avgPaceSecPerKm })
            let bestPace = runSessions
                .filter { $0.distanceMeters > 500 && $0.avgPaceSecPerKm > 0 }
                .min(by: { $0.avgPaceSecPerKm < $1.avgPaceSecPerKm })
            let longest = sessions.max(by: { $0.distanceMeters < $1.distanceMeters })

            HStack(spacing: 12) {
                bestPreviewTile(
                    label: "5K Best",
                    value: best5k.map { s in
                        let t = s.avgPaceSecPerKm * 5
                        return String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
                    } ?? "—",
                    icon: "figure.run",
                    color: .orange
                )
                Divider().frame(height: 44)
                bestPreviewTile(
                    label: "Best Pace",
                    value: bestPace.map { $0.formattedPace(useKm: useKm) } ?? "—",
                    icon: "speedometer",
                    color: .purple
                )
                Divider().frame(height: 44)
                bestPreviewTile(
                    label: "Longest",
                    value: longest.map { $0.formattedDistance(useKm: useKm) } ?? "—",
                    icon: "ruler",
                    color: .blue
                )
            }
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 12))
        }
        .appCard()
    }

    private func bestPreviewTile(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 5) {
            ZStack {
                Circle().fill(color.opacity(0.12)).frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Recent Sessions Card

    private var recentSessionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "Recent Sessions", icon: "clock.fill", color: .blue)
                Spacer()
                if sessions.count > 5 {
                    Button { showHistory = true } label: {
                        Text("See All").font(.caption.weight(.semibold)).foregroundStyle(.blue)
                    }
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(sessions.prefix(5).enumerated()), id: \.element.id) { idx, session in
                    NavigationLink(destination: CardioSessionDetailView(session: session)) {
                        sessionRow(session)
                    }
                    .buttonStyle(.plain)
                    if idx < min(sessions.count, 5) - 1 { Divider().padding(.leading, 58) }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    private func sessionRow(_ session: CardioSession) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(session.type.color.opacity(0.12)).frame(width: 44, height: 44)
                Image(systemName: session.type.icon)
                    .font(.system(size: 18, weight: .semibold)).foregroundStyle(session.type.color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(session.title).font(.subheadline.weight(.semibold))
                HStack(spacing: 8) {
                    Text(session.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                        .font(.caption).foregroundStyle(.secondary)
                    Text("·").foregroundStyle(.tertiary)
                    Text(session.formattedDistance(useKm: useKm))
                        .font(.caption.bold()).foregroundStyle(session.type.color)
                    Text("·").foregroundStyle(.tertiary)
                    Text(session.formattedDuration)
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(session.formattedPace(useKm: useKm))
                    .font(.caption.bold().monospacedDigit())
                Text("pace").font(.caption2).foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    // MARK: - Empty State

    private var emptyStateCard: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(Color.orange.opacity(0.12)).frame(width: 70, height: 70)
                Image(systemName: "figure.run")
                    .font(.system(size: 28, weight: .semibold)).foregroundStyle(.orange)
            }
            VStack(spacing: 6) {
                Text("No cardio sessions yet").font(.headline)
                Text("Start your first run or walk to see your stats here.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            Button {
                navigateToSession = true
            } label: {
                Text("Start First Session")
                    .font(.subheadline.bold()).padding(.horizontal, 24).padding(.vertical, 12)
                    .background(Color.orange.gradient).foregroundStyle(.white).clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
        .appCard()
    }

    // MARK: - Type picker (unused — inline picker used instead)

    private var typePickerSheet: some View {
        NavigationStack {
            List(CardioType.allCases) { type in
                Button {
                    selectedType = type
                    showTypePicker = false
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10).fill(type.color.opacity(0.12)).frame(width: 40, height: 40)
                            Image(systemName: type.icon).font(.system(size: 18)).foregroundStyle(type.color)
                        }
                        Text(type.rawValue).font(.subheadline.weight(.semibold))
                        Spacer()
                        if selectedType == type {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(type.color)
                        }
                    }
                }
            }
            .navigationTitle("Activity Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showTypePicker = false }
                }
            }
        }
    }
}
