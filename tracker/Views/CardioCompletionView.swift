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

    @State private var appeared = false
    @State private var notes = ""
    @FocusState private var notesFocused: Bool

    private var prs: [CardioPR] {
        cardioSessionPRs(session: session, allSessions: allSessions, useKm: useKm)
    }

    var body: some View {
        ZStack {
            // Background gradient matching activity type
            LinearGradient(
                colors: [session.type.color, session.type.color.opacity(0.55)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle().fill(.white.opacity(0.06)).frame(width: 300).offset(x: 130, y: -200)
            Circle().fill(.white.opacity(0.04)).frame(width: 180).offset(x: -80, y: 250)

            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 60)

                    // Trophy / icon
                    ZStack {
                        Circle().fill(.white.opacity(0.18)).frame(width: 110, height: 110)
                        Circle().fill(.white.opacity(0.10)).frame(width: 82, height: 82)
                        Image(systemName: prs.isEmpty ? "checkmark.circle.fill" : "trophy.fill")
                            .font(.system(size: 46, weight: .semibold))
                            .foregroundStyle(.white)
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
                        Rectangle().fill(.white.opacity(0.3)).frame(width: 1, height: 36)
                        completionStat(label: "Duration", value: session.formattedDuration)
                        Rectangle().fill(.white.opacity(0.3)).frame(width: 1, height: 36)
                        completionStat(label: "Avg Pace", value: session.formattedPace(useKm: useKm))
                    }
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 16))
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
                            miniStat(icon: "heart.fill", value: "\(Int(hr))", label: "bpm", color: .red.opacity(0.9))
                        }
                    }
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.4), value: appeared)

                    // PRs section
                    if !prs.isEmpty {
                        VStack(spacing: 10) {
                            ForEach(prs) { pr in
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle().fill(.white.opacity(0.2)).frame(width: 40, height: 40)
                                        Image(systemName: pr.icon)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(pr.label)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.white.opacity(0.75))
                                        Text(pr.value)
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.white)
                                    }
                                    Spacer()
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(.yellow)
                                        .font(.system(size: 14))
                                }
                                .padding(.horizontal, 16).padding(.vertical, 10)
                                .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
                            }
                        }
                        .padding(.horizontal, 24)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.5), value: appeared)
                    }

                    // Notes field
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Add a note", systemImage: "note.text")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.7))
                        TextField("How did it feel?", text: $notes, axis: .vertical)
                            .lineLimit(2...4)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .tint(.white)
                            .focused($notesFocused)
                            .padding(12)
                            .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 24)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.52), value: appeared)

                    Spacer(minLength: 16)

                    // Action buttons
                    VStack(spacing: 12) {
                        Button {
                            session.notes = notes
                            onDone()
                        } label: {
                            Text("View Full Report")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(.white)
                                .foregroundStyle(session.type.color)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)

                        Button {
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
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.55), value: appeared)
                }
            }
        }
        .onAppear { appeared = true }
    }

    private func completionStat(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }

    private func miniStat(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 10, weight: .semibold)).foregroundStyle(color)
                Text(value).font(.system(size: 14, weight: .bold, design: .rounded)).monospacedDigit().foregroundStyle(.white)
            }
            Text(label).font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.65))
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }
}
