import SwiftUI
import SwiftData
import UIKit
import UserNotifications

struct FinishWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.weightUnit) private var weightUnit
    @Environment(\.appServices) private var appServices
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

    private var sessionPRs: [FinishWorkoutSessionPR] {
        FinishWorkoutSummarySection.sessionPRs(workout: workout, allExercises: allExercises)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.sectionSpacing) {
                    FinishWorkoutSummarySection.celebrationCard(
                        workout: workout,
                        rating: $rating,
                        ratingLabel: ratingLabel
                    )
                    FinishWorkoutSummarySection.statsCard(
                        workout: workout,
                        totalSets: totalSets,
                        totalVolume: totalVolume,
                        weightUnit: weightUnit
                    )
                    if !sessionPRs.isEmpty {
                        FinishWorkoutSummarySection.prCard(sessionPRs: sessionPRs, weightUnit: weightUnit)
                    }
                    FinishWorkoutFeedbackSection.feelCard(feel: $feel)
                    let trained = FinishWorkoutFeedbackSection.trainedGroupsForSoreness(workout: workout)
                    if !trained.isEmpty {
                        FinishWorkoutFeedbackSection.sorenessCard(
                            trainedGroups: trained,
                            sorenessLevels: $sorenessLevels
                        )
                    }
                    FinishWorkoutFeedbackSection.notesCard(notes: $notes)
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
                            await appServices.openSettings()
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
                    .accessibilityLabel("Share workout")
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

        for (group, level) in sorenessLevels where level > 0 {
            let entry = SorenessEntry(date: .now, group: group, level: level)
            modelContext.insert(entry)
        }

        if let feel {
            let suggested = TodayPlanStore.load()?.intensity
            let event = WorkoutFeedbackEvent(day: .now, feel: feel, suggested: suggested)
            modelContext.insert(event)
        }

        let totalSets = workout.exercises.flatMap(\.sets).count
        appServices.workoutActivity.endActivity(
            exerciseCount: workout.exercises.count,
            setCount: totalSets
        )

        appServices.phoneConnectivity.publishActiveWorkout(name: nil, startedAt: nil)

        if settingsArray.first?.healthKitEnabled == true {
            Task {
                do {
                    try await appServices.healthKit.saveStrengthWorkout(workout)
                } catch {
                    appServices.appErrorBus.report(message: "Couldn't save workout to Apple Health.", kind: .warning)
                }
            }
        }

        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        ReminderManager.cancelTodayStreakNudge()

        if shouldPromptForReminders {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                showingReminderPrompt = true
            }
        }

        let settings = settingsArray.first ?? UserSettings()
        MetriclySyncCoordinator.publishAfterWorkoutFinishAndRefresh(
            workout: workout,
            settings: settings,
            modelContainer: modelContext.container
        )

        dismiss()
    }
}
