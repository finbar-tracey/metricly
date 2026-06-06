import SwiftUI

enum CardioHubSections {

    static func heroCard(
        totalDistanceKm: Double,
        sessionCount: Int,
        thisWeekDistanceKm: Double,
        useKm: Bool
    ) -> some View {
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
                    HeroStatCol(value: "\(sessionCount)", label: "Sessions")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 36)
                    HeroStatCol(
                        value: String(format: "%.1f %@", distUnit.display(thisWeekDistanceKm), distUnit.label),
                        label: "This Week"
                    )
                }
                .padding(.vertical, 12)
                .background(.ultraThinMaterial.opacity(0.55), in: RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 0.5)
                )
            }
            .padding(20)
        }
        .frame(minHeight: 145)
    }

    static func startCard(
        selectedType: Binding<CardioType>,
        onStart: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Start Activity", icon: "play.circle.fill", color: .orange)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(CardioType.allCases) { type in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedType.wrappedValue = type
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: type.icon)
                                    .font(.system(size: 13, weight: .bold))
                                Text(type.rawValue)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(selectedType.wrappedValue == type ? .white : .primary)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background {
                                if selectedType.wrappedValue == type {
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
                        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: selectedType.wrappedValue)
                    }
                }
                .padding(.horizontal, 2)
            }

            Button(action: onStart) {
                HStack(spacing: 10) {
                    Image(systemName: selectedType.wrappedValue.icon)
                        .font(.system(size: 18, weight: .semibold))
                    Text("Start \(selectedType.wrappedValue.rawValue)")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [selectedType.wrappedValue.color, selectedType.wrappedValue.color.opacity(0.75)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.tileRadius))
                .shadow(color: selectedType.wrappedValue.color.opacity(0.35), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
        }
        .appCard()
    }

    static func personalBestsCard(
        sessions: [CardioSession],
        useKm: Bool,
        onSeeAll: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "Personal Bests", icon: "trophy.fill", color: .yellow)
                Spacer()
                Button(action: onSeeAll) {
                    Text("See All").font(.caption.weight(.semibold)).foregroundStyle(.orange)
                }
            }

            let runSessions = sessions.filter {
                $0.cardioType == CardioType.outdoorRun.rawValue || $0.cardioType == CardioType.indoorRun.rawValue
            }
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
            .background(
                Color(.tertiarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 12)
            )
        }
        .appCard()
    }

    static func recentSessionsCard(
        sessions: [CardioSession],
        useKm: Bool,
        onSeeAll: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "Recent Sessions", icon: "clock.fill", color: .blue)
                Spacer()
                if sessions.count > 5 {
                    Button(action: onSeeAll) {
                        Text("See All").font(.caption.weight(.semibold)).foregroundStyle(.blue)
                    }
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(sessions.prefix(5).enumerated()), id: \.element.id) { idx, session in
                    NavigationLink(destination: CardioSessionDetailView(session: session)) {
                        sessionRow(session, useKm: useKm)
                    }
                    .buttonStyle(.plain)
                    if idx < min(sessions.count, 5) - 1 { Divider().padding(.leading, 58) }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.tileRadius))
        }
        .appCard()
    }

    static func emptyStateCard(onStart: @escaping () -> Void) -> some View {
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
            Button(action: onStart) {
                Text("Start First Session")
                    .font(.subheadline.bold()).padding(.horizontal, 24).padding(.vertical, 12)
                    .background(Color.orange.gradient).foregroundStyle(.white).clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
        .appCard()
    }

    static func typePickerSheet(
        selectedType: Binding<CardioType>,
        isPresented: Binding<Bool>
    ) -> some View {
        NavigationStack {
            List(CardioType.allCases) { type in
                Button {
                    selectedType.wrappedValue = type
                    isPresented.wrappedValue = false
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: AppTheme.chipRadius).fill(type.color.opacity(0.12)).frame(width: 40, height: 40)
                            Image(systemName: type.icon).font(.system(size: 18)).foregroundStyle(type.color)
                        }
                        Text(type.rawValue).font(.subheadline.weight(.semibold))
                        Spacer()
                        if selectedType.wrappedValue == type {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(type.color)
                        }
                    }
                }
            }
            .navigationTitle("Activity Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented.wrappedValue = false }
                }
            }
        }
    }

    // MARK: - Private

    private static func bestPreviewTile(label: String, value: String, icon: String, color: Color) -> some View {
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

    private static func sessionRow(_ session: CardioSession, useKm: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.chipRadius).fill(session.type.color.opacity(0.12)).frame(width: 44, height: 44)
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
}
