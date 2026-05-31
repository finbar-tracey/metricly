import SwiftUI
import WatchKit

// MARK: - Pre-workout

extension WatchGymView {

    var preWorkoutView: some View {
        ScrollView {
            VStack(spacing: 10) {
                if let started = connectivity.phoneActiveStartedAt {
                    Button {
                        showingFinishPhoneConfirm = true
                    } label: {
                        phoneActiveBanner(name: connectivity.phoneActiveName,
                                          startedAt: started)
                    }
                    .buttonStyle(.plain)
                }

                if !connectivity.adaptivePlanName.isEmpty {
                    adaptivePlanCard
                }

                if !connectivity.todayPlanName.isEmpty {
                    todaysPlanCard
                }

                Button {
                    startWorkout()
                } label: {
                    Label(connectivity.todayPlannedExercises.isEmpty
                          ? "Start Gym"
                          : "Start \(connectivity.todayPlanName)",
                          systemImage: "dumbbell.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
            .padding()
        }
        .navigationTitle("Gym")
        .confirmationDialog(
            "Finish phone workout?",
            isPresented: $showingFinishPhoneConfirm,
            titleVisibility: .visible
        ) {
            Button("Finish Now") {
                connectivity.sendFinishActiveWorkout()
                WKInterfaceDevice.current().play(.success)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Saves the workout on your iPhone with the current time.")
        }
    }

    func phoneActiveBanner(name: String, startedAt: Date) -> some View {
        let elapsed = Int(Date.now.timeIntervalSince(startedAt))
        return HStack(spacing: 8) {
            Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                .font(.caption.bold())
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 1) {
                Text("On iPhone")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.green)
                    .textCase(.uppercase)
                    .tracking(0.4)
                Text(name.isEmpty ? "Workout" : name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
            Text(formatDuration(elapsed))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.green.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Workout running on iPhone, \(name), \(formatDuration(elapsed)) elapsed")
    }

    var todaysPlanCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.caption2)
                    .foregroundStyle(.blue)
                Text("Today")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            Text(connectivity.todayPlanName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if !connectivity.todayPlannedExercises.isEmpty {
                Text(connectivity.todayPlannedExercises.prefix(4).joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if connectivity.todayPlannedExercises.count > 4 {
                    Text("+\(connectivity.todayPlannedExercises.count - 4) more")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.blue.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
    }

    var adaptivePlanCard: some View {
        let cardTint = adaptiveCardTint
        let badgeLabel = adaptiveBadgeText
        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption2)
                    .foregroundStyle(cardTint)
                Text("Today's Plan")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer(minLength: 0)
                if let label = badgeLabel {
                    Text(label.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(cardTint)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(cardTint.opacity(0.22), in: Capsule())
                }
            }

            Text(connectivity.adaptivePlanName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if !connectivity.blockWeekLabel.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: blockGlyph)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(cardTint)
                    Text(blockStripText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }

            if !connectivity.adaptiveTopReason.isEmpty {
                Text(connectivity.adaptiveTopReason)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(cardTint.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(adaptiveAccessibilityLabel)
    }

    var adaptiveCardTint: Color {
        if connectivity.adaptiveIntensity == "rest" { return .gray }
        if connectivity.blockPhase == "deload"      { return .purple }
        return intensityTint(connectivity.adaptiveIntensity)
    }

    var adaptiveBadgeText: String? {
        if connectivity.adaptiveIntensity == "rest" { return "Rest" }
        if connectivity.blockPhase == "deload"      { return "Deload" }
        switch connectivity.adaptiveIntensity {
        case "light": return "Light"
        case "hard":  return "Hard"
        default:      return nil
        }
    }

    var blockStripText: String {
        let compact = connectivity.blockWeekLabel
            .replacingOccurrences(of: "Week ", with: "Wk ")
            .replacingOccurrences(of: " of ", with: "/")
        guard !connectivity.blockPhase.isEmpty else { return compact }
        let phaseLabel = connectivity.blockPhase.capitalized
        return "\(compact) · \(phaseLabel)"
    }

    var blockGlyph: String {
        switch connectivity.blockPhase {
        case "deload":     return "arrow.down.right"
        case "accumulate": return "arrow.up.right"
        default:           return "calendar"
        }
    }

    var adaptiveAccessibilityLabel: String {
        var parts = ["Today's plan", connectivity.adaptivePlanName]
        if !connectivity.adaptiveIntensity.isEmpty {
            parts.append("\(connectivity.adaptiveIntensity) intensity")
        }
        if !connectivity.blockWeekLabel.isEmpty {
            let phaseSpoken = connectivity.blockPhase.isEmpty
                ? ""
                : ", \(connectivity.blockPhase) block"
            parts.append("\(connectivity.blockWeekLabel)\(phaseSpoken)")
        }
        if !connectivity.adaptiveTopReason.isEmpty {
            parts.append(connectivity.adaptiveTopReason)
        }
        return parts.joined(separator: ", ")
    }
}
