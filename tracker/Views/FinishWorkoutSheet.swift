import SwiftUI
import SwiftData
import UIKit
import UserNotifications

struct FinishWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.weightUnit) private var weightUnit
    @Query private var settingsArray: [UserSettings]
    @Query(filter: #Predicate<Exercise> { $0.workout?.isTemplate == false })
    private var allExercises: [Exercise]
    let workout: Workout

    @Query(filter: #Predicate<Workout> { !$0.isTemplate }, sort: \Workout.date, order: .reverse)
    private var allWorkouts: [Workout]

    @State private var rating: Int = 0
    @State private var notes: String
    @State private var shareImage: UIImage?
    @State private var showingShare = false
    @State private var showingReminderPrompt = false
    /// Per-muscle-group soreness level the user picks. Only groups
    /// trained in this workout appear in the UI. 0 = none (not stored).
    @State private var sorenessLevels: [MuscleGroup: Int] = [:]
    /// User-reported "how did it feel?" — optional, defaults to nil
    /// (skip persisting). Drives the engine's user-feedback signal
    /// alongside the inferred trust-calibration loop.
    @State private var feel: WorkoutFeedbackEvent.Feel?
    @Environment(\.modelContext) private var modelContext

    init(workout: Workout) {
        self.workout = workout
        _notes = State(initialValue: workout.notes)
    }

    /// True when this is the user's first completed workout and they haven't set reminders yet.
    private var shouldPromptForReminders: Bool {
        allWorkouts.count <= 1 && (settingsArray.first?.reminderDays.isEmpty ?? true)
    }

    private var totalVolume: Double {
        workout.exercises.flatMap(\.sets).filter { !$0.isWarmUp }.reduce(0) { $0 + Double($1.reps) * $1.weight }
    }

    private var totalSets: Int {
        workout.exercises.flatMap(\.sets).filter { !$0.isWarmUp }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.sectionSpacing) {
                    celebrationCard
                    statsCard
                    if !sessionPRs.isEmpty { prCard }
                    feelCard
                    if !trainedGroupsForSoreness.isEmpty { sorenessCard }
                    notesCard
                }
                .padding(.horizontal)
                .padding(.bottom, 36)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(String(
                localized: "Workout Complete",
                comment: "Navigation title on the finish-workout summary sheet"
            ))
            .navigationBarTitleDisplayMode(.inline)
            .alert(String(localized: "Stay consistent 🔥",
                          comment: "Alert title prompting the user to set up workout reminders"),
                   isPresented: $showingReminderPrompt) {
                Button(String(localized: "Set Reminder",
                              comment: "Alert button that opens the reminder setup")) {
                    // Request permission then open Settings to let user pick days
                    Task {
                        let status = await ReminderManager.checkAuthorizationStatus()
                        if status == .denied {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                await UIApplication.shared.open(url)
                            }
                        } else {
                            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
                        }
                    }
                }
                Button(String(localized: "Maybe Later",
                              comment: "Dismiss button on the reminder-prompt alert"),
                       role: .cancel) {}
            } message: {
                Text(String(
                    localized: "Want Metricly to remind you on your training days? You can set this up in Settings anytime.",
                    comment: "Body text of the reminder-setup prompt alert"
                ))
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel",
                                  comment: "Toolbar button to dismiss the finish-workout sheet")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        shareImage = renderWorkoutShareImage(workout: workout, weightUnit: weightUnit)
                        showingShare = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done",
                                  comment: "Toolbar button that commits the workout summary")) {
                        finishWorkout()
                    }
                    .font(.headline)
                }
            }
            .sheet(isPresented: $showingShare) {
                if let img = shareImage {
                    ShareSheet(items: [img])
                }
            }
        }
    }

    // MARK: - Celebration hero card

    private var celebrationCard: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: AppTheme.Gradients.recovery,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(.white.opacity(0.07))
                .frame(width: 200)
                .offset(x: 170, y: -60)

            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.20))
                            .frame(width: 56, height: 56)
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(String(localized: "Great work!",
                                    comment: "Celebration headline on the finish-workout hero card"))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                        Text(workout.name)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.75))
                            .lineLimit(1)
                    }
                }

                // Star rating
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "How was it?",
                                comment: "Prompt above the star rating row on the hero card"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))

                    HStack(spacing: 12) {
                        ForEach(1...5, id: \.self) { value in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    rating = value
                                }
                            } label: {
                                Image(systemName: value <= rating ? "star.fill" : "star")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundStyle(value <= rating ? .yellow : .white.opacity(0.50))
                                    .scaleEffect(value <= rating ? 1.18 : 1.0)
                                    .shadow(color: value <= rating ? Color.yellow.opacity(0.55) : .clear, radius: 6, y: 1)
                            }
                            .buttonStyle(.pressableCard)
                            .accessibilityLabel("\(value) star\(value == 1 ? "" : "s")")
                            .accessibilityAddTraits(value <= rating ? .isSelected : [])
                        }

                        if rating > 0 {
                            Text(ratingLabel)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.85))
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            }
            .padding(20)
        }
        .heroCard()
    }

    // MARK: - Stats card

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: String(localized: "Summary",
                              comment: "Section header above the duration / exercises / sets / volume stat strip"),
                icon: "chart.bar.fill", color: .accentColor
            )

            HStack(spacing: 0) {
                finishStat(icon: "clock",
                           value: workout.formattedDuration ?? "-",
                           label: String(localized: "Duration",
                                         comment: "Stat label under workout duration"),
                           color: .orange)
                Divider().frame(height: 50)
                finishStat(icon: "figure.strengthtraining.functional",
                           value: "\(workout.exercises.count)",
                           label: String(localized: "Exercises",
                                         comment: "Stat label under the exercise count"),
                           color: .accentColor)
                Divider().frame(height: 50)
                finishStat(icon: "repeat",
                           value: "\(totalSets)",
                           label: String(localized: "Sets",
                                         comment: "Stat label under the working-set count"),
                           color: .purple)
                Divider().frame(height: 50)
                finishStat(icon: "scalemass",
                           value: formatVolume(totalVolume),
                           label: String(localized: "Volume",
                                         comment: "Stat label under the total weight lifted"),
                           color: .green)
            }
            .padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
            .shadow(color: .black.opacity(0.07), radius: 12, x: 0, y: 3)
        }
    }

    private func finishStat(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Soreness card
    //
    // Optional user-reported soreness for groups this workout trained.
    // Defaults to "None" — only non-zero entries are persisted. Feeds
    // RecoveryEngine as a third intensity signal alongside volume and
    // RPE; the user's own input wins when it conflicts with the model.

    /// Trainable muscle groups this workout actually targeted (with at
    /// least one working set). Filters out cardio/other so the section
    /// only surfaces actionable choices.
    private var trainedGroupsForSoreness: [MuscleGroup] {
        let groups = workout.exercises.compactMap { exercise -> MuscleGroup? in
            guard let cat = exercise.category, cat != .cardio, cat != .other else { return nil }
            let hasWorkingSet = exercise.sets.contains { !$0.isWarmUp }
            return hasWorkingSet ? cat : nil
        }
        return Array(Set(groups)).sorted { $0.rawValue < $1.rawValue }
    }

    private var sorenessCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: String(localized: "How sore are you?",
                              comment: "Section header above the per-muscle soreness picker"),
                icon: "figure.cooldown", color: .purple
            )
            .accessibilityAddTraits(.isHeader)

            Text(String(
                localized: "Optional — tells the recovery engine where you actually feel it.",
                comment: "Caption under the soreness section explaining it's optional"
            ))
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(trainedGroupsForSoreness, id: \.self) { group in
                    HStack(spacing: 10) {
                        Text(group.rawValue)
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        sorenessPicker(for: group)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .appCard()
    }

    private func sorenessPicker(for group: MuscleGroup) -> some View {
        let level = sorenessLevels[group] ?? 0
        return HStack(spacing: 4) {
            ForEach(0...4, id: \.self) { value in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    sorenessLevels[group] = value
                } label: {
                    let isSelected = value == level
                    Circle()
                        .fill(isSelected ? severityColor(value) : Color(.tertiarySystemGroupedBackground))
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle().stroke(isSelected ? severityColor(value) : Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                        .overlay(
                            Text("\(value)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(isSelected ? .white : .secondary)
                        )
                        .accessibilityLabel("\(SorenessEntry.Level(rawValue: value)?.label ?? "level \(value)") soreness for \(group.rawValue)")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func severityColor(_ level: Int) -> Color {
        SorenessEntry.Level.tint(forLevel: level)
    }

    // MARK: - "How did it feel?" card
    //
    // Optional user feedback — the reported counterpart to
    // PlanComplianceEvent's inferred signal. Feeds
    // TodayPlanEngine.recentFeedback; when a majority pattern
    // emerges, the engine surfaces a reason line on the home
    // dashboard. Three buttons, single-select, defaults to nil so
    // skipping is the obvious path for users who don't want to engage.

    private var feelCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: String(localized: "How did it feel?",
                              comment: "Section header above the post-workout feel picker"),
                icon: "thermometer.medium",
                color: .pink
            )
            .accessibilityAddTraits(.isHeader)

            Text(String(
                localized: "Optional — helps Metricly tune your next plan to match what you felt.",
                comment: "Caption under the post-workout feel picker explaining it's optional"
            ))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(WorkoutFeedbackEvent.Feel.allCases) { option in
                    feelButton(option)
                }
            }
        }
    }

    private func feelButton(_ option: WorkoutFeedbackEvent.Feel) -> some View {
        let isSelected = feel == option
        let tint = feelTint(for: option)
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                // Tapping the already-selected button clears the
                // selection — gives the user an undo path without a
                // separate "skip" button.
                feel = isSelected ? nil : option
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: option.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : tint)
                Text(option.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? tint : Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? tint : Color.secondary.opacity(0.18),
                            lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Tint per feel — blue for "easy" (cool), green for "right", red
    /// for "hard" (warm). Matches the broader Signal palette so the
    /// row reads as a temperature gauge.
    private func feelTint(for option: WorkoutFeedbackEvent.Feel) -> Color {
        switch option {
        case .tooEasy:    return AppTheme.Signal.calm
        case .aboutRight: return AppTheme.Signal.recovery
        case .tooHard:    return AppTheme.Signal.strain
        }
    }

    // MARK: - Notes card

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: String(localized: "Notes",
                              comment: "Section header above the workout notes text field"),
                icon: "note.text", color: .secondary
            )

            TextField(String(localized: "How did it feel? Any notes...",
                             comment: "Placeholder text inside the workout notes field"),
                      text: $notes, axis: .vertical)
                .lineLimit(3...6)
                .font(.subheadline)
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        }
    }

    // MARK: - PR Detection

    struct SessionPR: Identifiable {
        let id = UUID()
        let exerciseName: String
        let weight: Double
    }

    private var sessionPRs: [SessionPR] {
        var prs: [SessionPR] = []
        for exercise in workout.exercises {
            let sessionBest = exercise.sets.filter { !$0.isWarmUp }.map(\.weight).max() ?? 0
            guard sessionBest > 0 else { continue }
            // Historical best = max weight across all OTHER instances of this exercise
            let historicalBest = allExercises
                .filter { other in
                    other.name.lowercased() == exercise.name.lowercased()
                    && other.persistentModelID != exercise.persistentModelID
                    && !(other.workout?.isTemplate ?? true)
                }
                .flatMap(\.sets)
                .filter { !$0.isWarmUp }
                .map(\.weight)
                .max() ?? 0
            if sessionBest > historicalBest {
                prs.append(SessionPR(exerciseName: exercise.name, weight: sessionBest))
            }
        }
        return prs
    }

    // MARK: - PR Card

    private var prCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: String(localized: "Personal Records",
                              comment: "Section header above the PRs achieved in this session"),
                icon: "trophy.fill", color: .yellow
            )

            VStack(spacing: 0) {
                ForEach(sessionPRs) { pr in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color.yellow.opacity(0.15)).frame(width: 36, height: 36)
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.yellow)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pr.exerciseName)
                                .font(.subheadline.weight(.semibold))
                            Text(String(
                                localized: "New best: \(weightUnit.format(pr.weight))",
                                comment: "Subtitle on a PR row; placeholder is the weight string e.g. '120 kg'"
                            ))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "star.fill")
                            .font(.caption).foregroundStyle(.yellow)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    if pr.id != sessionPRs.last?.id {
                        Divider().padding(.leading, 62)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        }
    }

    // MARK: - Helpers

    private func formatVolume(_ volumeKg: Double) -> String {
        let value = weightUnit.display(volumeKg)
        if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        }
        return String(format: "%.0f", value)
    }

    private var ratingLabel: String {
        switch rating {
        case 1: return String(localized: "Rough",
                              comment: "1-star rating label on the post-workout self-rating row")
        case 2: return String(localized: "Okay",
                              comment: "2-star rating label on the post-workout self-rating row")
        case 3: return String(localized: "Decent",
                              comment: "3-star rating label on the post-workout self-rating row")
        case 4: return String(localized: "Great",
                              comment: "4-star rating label on the post-workout self-rating row")
        case 5: return String(localized: "Crushed it!",
                              comment: "5-star rating label on the post-workout self-rating row")
        default: return ""
        }
    }

    private func finishWorkout() {
        workout.endTime = .now
        workout.notes = notes
        if rating > 0 { workout.rating = rating }

        // Persist any non-zero soreness reports. Level 0 is "none" and
        // doesn't need a row — absence implies that. The engine reads
        // these via @Query in HomeDashboardView and stacks them with
        // the model's volume/RPE estimate.
        for (group, level) in sorenessLevels where level > 0 {
            let entry = SorenessEntry(date: .now, group: group, level: level)
            modelContext.insert(entry)
        }

        // User feedback ("how did it feel?") — optional. If the user
        // tapped a feel, store a `WorkoutFeedbackEvent` tagged with
        // the day and the engine's suggested intensity at capture
        // time (read from `TodayPlanStore`). The engine reads recent
        // events via @Query in HomeDashboardView and surfaces a
        // reason line when a clear majority pattern emerges.
        if let feel {
            let suggested = TodayPlanStore.load()?.intensity
            let event = WorkoutFeedbackEvent(
                day: .now,
                feel: feel,
                suggested: suggested
            )
            modelContext.insert(event)
        }

        let totalSets = workout.exercises.flatMap(\.sets).count
        WorkoutActivityManager.shared.endActivity(
            exerciseCount: workout.exercises.count,
            setCount: totalSets
        )

        // Clear the Watch's "In Progress" state — paired with the publish
        // call in AddWorkoutSheet.createWorkout when the session started.
        PhoneConnectivityManager.shared.publishActiveWorkout(name: nil, startedAt: nil)

        if settingsArray.first?.healthKitEnabled == true {
            Task {
                do {
                    try await HealthKitManager.shared.saveStrengthWorkout(workout)
                } catch {
                    AppErrorBus.shared.report(message: "Couldn't save workout to Apple Health.", kind: .warning)
                }
            }
        }

        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        // Cancel today's streak nudge — user has already worked out
        ReminderManager.cancelTodayStreakNudge()

        // First-workout nudge: prompt to set up reminders
        if shouldPromptForReminders {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                showingReminderPrompt = true
            }
        }

        // Push fresh data to home screen widget — only the fields we know about.
        // Streak / weekly counts are recomputed by ContentView's full update.
        WidgetDataWriter.update(
            todayWorkoutName: workout.name,
            weeklyGoal: settingsArray.first?.weeklyGoal
        )

        dismiss()
    }
}
