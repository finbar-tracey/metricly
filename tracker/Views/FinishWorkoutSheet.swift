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
                    notesCard
                }
                .padding(.horizontal)
                .padding(.bottom, 36)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Workout Complete")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Stay consistent 🔥", isPresented: $showingReminderPrompt) {
                Button("Set Reminder") {
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
                Button("Maybe Later", role: .cancel) {}
            } message: {
                Text("Want Metricly to remind you on your training days? You can set this up in Settings anytime.")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
                    Button("Done") { finishWorkout() }
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
                colors: [Color.green, Color(red: 0.1, green: 0.72, blue: 0.35).opacity(0.7)],
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
                        Text("Great work!")
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
                    Text("How was it?")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))

                    HStack(spacing: 12) {
                        ForEach(1...5, id: \.self) { value in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    rating = value
                                }
                            } label: {
                                Image(systemName: value <= rating ? "star.fill" : "star")
                                    .font(.title2)
                                    .foregroundStyle(value <= rating ? .yellow : .white.opacity(0.50))
                                    .scaleEffect(value <= rating ? 1.15 : 1.0)
                            }
                            .buttonStyle(.plain)
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
            SectionHeader(title: "Summary", icon: "chart.bar.fill", color: .accentColor)

            HStack(spacing: 0) {
                finishStat(icon: "clock", value: workout.formattedDuration ?? "-", label: "Duration", color: .orange)
                Divider().frame(height: 50)
                finishStat(icon: "figure.strengthtraining.functional", value: "\(workout.exercises.count)", label: "Exercises", color: .accentColor)
                Divider().frame(height: 50)
                finishStat(icon: "repeat", value: "\(totalSets)", label: "Sets", color: .purple)
                Divider().frame(height: 50)
                finishStat(icon: "scalemass", value: formatVolume(totalVolume), label: "Volume", color: .green)
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

    // MARK: - Notes card

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Notes", icon: "note.text", color: .secondary)

            TextField("How did it feel? Any notes...", text: $notes, axis: .vertical)
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
            SectionHeader(title: "Personal Records", icon: "trophy.fill", color: .yellow)

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
                            Text("New best: \(weightUnit.format(pr.weight))")
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
        case 1: return "Rough"
        case 2: return "Okay"
        case 3: return "Decent"
        case 4: return "Great"
        case 5: return "Crushed it!"
        default: return ""
        }
    }

    private func finishWorkout() {
        workout.endTime = .now
        workout.notes = notes
        if rating > 0 { workout.rating = rating }

        let totalSets = workout.exercises.flatMap(\.sets).count
        WorkoutActivityManager.shared.endActivity(
            exerciseCount: workout.exercises.count,
            setCount: totalSets
        )

        if settingsArray.first?.healthKitEnabled == true {
            Task { try? await HealthKitManager.shared.saveStrengthWorkout(workout) }
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

        // Push fresh data to home screen widget
        WidgetDataWriter.update(
            streakDays: 0,          // caller doesn't have streak — widget reads from shared store; 0 = unchanged
            todayWorkoutName: workout.name,
            weeklyCardioKm: 0,
            lastRunPace: "",
            lastRunDist: "",
            weeklyGoal: settingsArray.first?.weeklyGoal ?? 0,
            workoutsThisWeek: 0     // widget re-computes from stored value
        )

        dismiss()
    }
}
