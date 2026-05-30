import SwiftUI
import SwiftData
import UIKit

struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.weightUnit) private var weightUnit
    @Environment(\.scenePhase) private var scenePhase
    @Query(filter: #Predicate<Exercise> { $0.workout?.isTemplate == false })
    private var allExercises: [Exercise]
    let workout: Workout
    @State private var newExerciseName = ""
    @State private var newExerciseCategory: MuscleGroup = .other
    @State private var showingEditWorkout = false
    @State private var showTemplateSaved = false
    @State private var showingSuggestions = false
    @State private var exerciseToDelete: Exercise?
    @State private var elapsedTime = ""
    @State private var durationTimer: Timer?
    @State private var linkingSupersetFor: Exercise?
    @State private var showingFinishSheet = false
    @State private var showingShare = false
    @State private var shareItems: [Any] = []
    @State private var showDeleteConfirm = false
    @State private var showWorkoutTimer = false
    @State private var showFocusPrompt = false
    @State private var showFocusEndReminder = false
    @State private var planAdjustments: TodayPlan?
    @State private var planAdjustmentsDismissed = false
    /// Exercises the user has dismissed substitution suggestions for
    /// in this view. PersistentModelID keys survive the @Query
    /// re-issuing the list on each set logged. Cleared when the user
    /// dismisses the whole adjustments banner (the substitution
    /// suggestions live alongside it).
    @State private var dismissedSubstitutions: Set<PersistentIdentifier> = []
    @Query private var settingsArray: [UserSettings]
    @Environment(\.dismiss) private var dismiss

    private var settings: UserSettings {
        settingsArray.first ?? UserSettings()
    }

    private var suggestions: [String] {
        let history = Set(allExercises.map(\.name))
        let current = Set(workout.exercises.map(\.name))
        let available = history.subtracting(current)
        if newExerciseName.isEmpty {
            return available.sorted()
        }
        return available.filter {
            $0.localizedCaseInsensitiveContains(newExerciseName)
        }.sorted()
    }

    var body: some View {
        List {
            // MARK: - Hero (non-template)
            if !workout.isTemplate {
                Section {
                    WorkoutHeroCard(
                        workout: workout,
                        weightUnit: weightUnit,
                        progressFraction: progressFraction,
                        progressRatio: progressRatio,
                        totalWorkingSets: totalWorkingSets,
                        elapsedTime: elapsedTime
                    )
                        .listRowBackground(Color.clear)
                        .listRowInsets(.init(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                // MARK: - Today's Plan adjustments
                if let plan = planAdjustments,
                   !plan.adjustments.isEmpty,
                   !planAdjustmentsDismissed,
                   !workout.isFinished {
                    // Preview is computed every render — cheap, and it
                    // updates automatically as the user logs sets so the
                    // Apply button vanishes once it's no longer useful.
                    let preview = TodayPlanApply.preview(plan: plan, on: workout)
                    Section {
                        TodayPlanAdjustmentsBanner(
                            plan: plan,
                            onDismiss: { withAnimation { planAdjustmentsDismissed = true } },
                            applyPreview: preview,
                            onApply: { applyPlanAdjustments(plan) }
                        )
                        .listRowBackground(Color.clear)
                        .listRowInsets(.init(top: 0, leading: 16, bottom: 8, trailing: 16))
                    }
                }

                // MARK: - Suggested substitutions
                // Soft alternative to the avoid-group removal in the
                // banner above — for unlogged exercises on fatigued
                // muscles, offer a less-fatiguing swap instead of
                // dropping them entirely. The user can Swap (rename in
                // place + clear sets) or Keep (dismiss the
                // suggestion).
                if let plan = planAdjustments,
                   !planAdjustmentsDismissed,
                   !workout.isFinished {
                    let suggestions = TodayPlanApply.substitutionsFor(plan: plan, on: workout)
                        .filter { !dismissedSubstitutions.contains($0.exercise.persistentModelID) }
                    if !suggestions.isEmpty {
                        Section {
                            substitutionsCard(suggestions)
                                .listRowBackground(Color.clear)
                                .listRowInsets(.init(top: 0, leading: 16, bottom: 8, trailing: 16))
                        }
                    }
                }
            }

            // MARK: - Notes
            Section {
                NavigationLink {
                    WorkoutNotesView(workout: workout)
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.12))
                                .frame(width: 32, height: 32)
                            Image(systemName: "note.text")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.blue)
                        }
                        if workout.notes.isEmpty {
                            Text("Add notes…")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        } else {
                            Text(LocalizedStringKey(workout.notes))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color(.secondarySystemGroupedBackground))
            } header: {
                SectionHeader(title: "Notes", icon: "note.text", color: .blue)
            }

            // MARK: - Empty state
            if workout.exercises.isEmpty {
                Section {
                    VStack(spacing: 14) {
                        Image(systemName: "figure.run")
                            .font(.system(size: 38))
                            .foregroundStyle(.tertiary)
                        Text("No Exercises Yet")
                            .font(.subheadline.weight(.semibold))
                        Text("Add an exercise below to get started.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .listRowBackground(Color.clear)
                }
            }

            // MARK: - Exercises
            if !workout.exercises.isEmpty {
                Section {
                    ForEach(sortedExercises) { exercise in
                        NavigationLink(value: exercise) {
                            WorkoutExerciseRow(
                                exercise: exercise,
                                weightUnit: weightUnit,
                                averageRPE: averageRPE(for: exercise),
                                badge: progressBadge(for: exercise)
                            )
                        }
                        .listRowBackground(Color(.secondarySystemGroupedBackground))
                        .swipeActions(edge: .leading) {
                            if exercise.supersetGroup != nil {
                                Button {
                                    unlinkSuperset(exercise)
                                } label: {
                                    Label("Unlink", systemImage: "link.badge.plus")
                                }
                                .tint(.orange)
                            } else {
                                Button {
                                    linkingSupersetFor = exercise
                                } label: {
                                    Label("Superset", systemImage: "link")
                                }
                                .tint(.purple)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(exerciseAccessibilityLabel(exercise))
                    }
                    .onDelete { offsets in
                        let sorted = sortedExercises
                        if let index = offsets.first {
                            exerciseToDelete = sorted[index]
                        }
                    }
                    .onMove(perform: moveExercises)
                } header: {
                    SectionHeader(
                        title: "Exercises (\(workout.exercises.count))",
                        icon: "dumbbell.fill",
                        color: .accentColor
                    )
                }
            }

            // MARK: - Add Exercise
            Section {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.12))
                            .frame(width: 32, height: 32)
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                    }
                    TextField("Exercise name", text: $newExerciseName)
                        .onChange(of: newExerciseName) {
                            showingSuggestions = !newExerciseName.isEmpty && !suggestions.isEmpty
                            autoSelectCategory()
                        }
                    Button {
                        addExercise()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                    }
                    .disabled(newExerciseName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityLabel("Add exercise")
                }
                .listRowBackground(Color(.secondarySystemGroupedBackground))

                Picker("Muscle Group", selection: $newExerciseCategory) {
                    ForEach(MuscleGroup.allCases) { group in
                        Label(group.rawValue, systemImage: group.icon).tag(group)
                    }
                }
                .listRowBackground(Color(.secondarySystemGroupedBackground))

                if showingSuggestions {
                    ForEach(suggestions.prefix(5), id: \.self) { suggestion in
                        Button {
                            newExerciseName = suggestion
                            showingSuggestions = false
                            autoSelectCategory()
                            addExercise()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
                                Text(suggestion)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(Color.accentColor)
                                    .font(.subheadline)
                            }
                        }
                        .listRowBackground(Color(.secondarySystemGroupedBackground))
                    }
                }
            } header: {
                SectionHeader(title: "Add Exercise", icon: "plus.circle.fill", color: .green)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(workout.name)
        .navigationDestination(for: Exercise.self) { exercise in
            ExerciseDetailView(exercise: exercise)
        }
        // MARK: - Gym Dock — sticky bottom bar for the in-workout primary loop
        .safeAreaInset(edge: .bottom) {
            if let active = activeDockExercise, !workout.isFinished, !workout.isTemplate {
                GymDockView(
                    exercise: active,
                    lastSet: lastWorkingSet(for: active),
                    suggestion: suggestionForDock(active),
                    weightUnitLabel: weightUnit == .kg ? "km" : "mi",
                    onAddSet: { quickAddSet(for: active) }
                )
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                // Finish — only while a non-template workout is in progress.
                // Was a giant gradient button under the hero; toolbar position
                // keeps it always reachable without burning vertical space.
                if !workout.isTemplate && !workout.isFinished {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showingFinishSheet = true
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    .accessibilityLabel("Finish workout")
                }

                Button {
                    showWorkoutTimer = true
                } label: {
                    Image(systemName: "stopwatch")
                }
                .accessibilityLabel("Workout Timers")

                Menu {
                    Button {
                        showingEditWorkout = true
                    } label: {
                        Label("Edit Workout", systemImage: "pencil")
                    }
                    Button {
                        saveAsTemplate()
                    } label: {
                        Label("Save as Template", systemImage: "doc.on.doc")
                    }
                    Button {
                        duplicateWorkout()
                    } label: {
                        Label("Duplicate Workout", systemImage: "plus.square.on.square")
                    }
                    Button {
                        shareItems = [WorkoutSummaryFormatter.plainText(for: workout, weightUnit: weightUnit)]
                        showingShare = true
                    } label: {
                        Label("Share as Text", systemImage: "text.quote")
                    }
                    Button {
                        let card = WorkoutShareCardView(workout: workout, weightUnit: weightUnit)
                        if let image = card.renderImage() {
                            shareItems = [image]
                            showingShare = true
                        }
                    } label: {
                        Label("Share as Image", systemImage: "photo")
                    }

                    Divider()

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete Workout", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More")
            }
        }
        .sheet(isPresented: $showingEditWorkout) {
            EditWorkoutSheet(workout: workout)
        }
        .sheet(isPresented: $showWorkoutTimer) {
            NavigationStack {
                WorkoutTimerView()
            }
        }
        .sheet(isPresented: $showingFinishSheet) {
            stopDurationTimer()
            if workout.isFinished {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                if settings.focusModeReminder {
                    showFocusEndReminder = true
                }
            }
        } content: {
            FinishWorkoutSheet(workout: workout)
        }
        .sheet(isPresented: $showingShare) {
            ShareSheet(items: shareItems)
        }
        .alert("Template Saved", isPresented: $showTemplateSaved) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\"\(workout.name)\" has been saved as a template. You can use it when creating new workouts.")
        }
        .alert("Delete Exercise?", isPresented: Binding(
            get: { exerciseToDelete != nil },
            set: { if !$0 { exerciseToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let exercise = exerciseToDelete {
                    modelContext.delete(exercise)
                    exerciseToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { exerciseToDelete = nil }
        } message: {
            if let exercise = exerciseToDelete {
                Text("Are you sure you want to delete \"\(exercise.name)\" and all its sets?")
            }
        }
        .confirmationDialog("Delete Workout?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete \"\(workout.name)\"", role: .destructive) {
                modelContext.delete(workout)
                dismiss()
            }
        } message: {
            Text("This will permanently delete this workout and all its data. This cannot be undone.")
        }
        .alert("Enable Focus Mode?", isPresented: $showFocusPrompt) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Not Now", role: .cancel) {}
        } message: {
            // Settings → Focus → Fitness can't be deep-linked from a
            // third-party app — Apple deprecated the `App-prefs:` scheme
            // (also a private API that risks App Review). Opening our own
            // settings page is the closest public entry point.
            Text("Enable your Fitness Focus to silence notifications during your workout. Open Settings, then tap Focus.")
        }
        .alert("Workout Complete!", isPresented: $showFocusEndReminder) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Don't forget to turn off your Fitness Focus mode. Open Settings, then tap Focus.")
        }
        .sheet(item: $linkingSupersetFor) { sourceExercise in
            SupersetPickerSheet(
                source: sourceExercise,
                candidates: sortedExercises.filter { $0.persistentModelID != sourceExercise.persistentModelID },
                onPick: { partner in
                    linkSuperset(sourceExercise, with: partner)
                    linkingSupersetFor = nil
                },
                onCancel: { linkingSupersetFor = nil }
            )
        }
        .onAppear {
            updateElapsedTime()
            startDurationTimer()
            startLiveActivityIfNeeded()
            if settings.focusModeReminder && !workout.isFinished && !workout.isTemplate {
                showFocusPrompt = true
            }
            // Pull today's plan once when entering — banner only shows
            // when this workout is *actually* the one the plan applies
            // to. Previously the banner attached to any unfinished
            // workout, so opening yesterday's abandoned session saw
            // today's adaptive advice land on the wrong workout.
            //
            // Four gates:
            //   1. The plan exists and the user hasn't already trained
            //      today (already-trained → no edits to make).
            //   2. The workout is dated today (no retroactive edits to
            //      historical sessions).
            //   3. The workout's name matches the plan's recommendation
            //      (case-insensitive) — applying "Push Day" adjustments
            //      to a "Legs" workout would actively trash the user's
            //      planned legs session.
            //   4. The plan isn't a rest day (nothing to adjust).
            if let plan = TodayPlanStore.load(),
               !plan.alreadyTrainedToday,
               Calendar.current.isDateInToday(workout.date),
               workout.name.localizedCaseInsensitiveCompare(plan.recommendedName) == .orderedSame,
               plan.intensity != .rest {
                planAdjustments = plan
            }
        }
        .onDisappear {
            stopDurationTimer()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && !workout.isFinished && !workout.isTemplate {
                updateElapsedTime()
                if durationTimer == nil {
                    startDurationTimer()
                }
            }
        }
    }

    // MARK: - Workout-level progress

    /// Number of exercises that have at least one working (non-warm-up) set.
    private var completedExercises: Int {
        workout.exercises.reduce(0) { total, ex in
            total + (ex.sets.contains { !$0.isWarmUp && $0.weight > 0 } ? 1 : 0)
        }
    }

    private var totalWorkingSets: Int {
        workout.exercises.flatMap(\.sets).filter { !$0.isWarmUp }.count
    }

    /// Display string for the hero's "Done" stat: "2/7" when there are
    /// exercises, "0/0" when the workout is empty.
    private var progressFraction: String {
        "\(completedExercises)/\(workout.exercises.count)"
    }

    /// 0...1 fraction for the under-stats progress bar.
    private var progressRatio: Double {
        guard !workout.exercises.isEmpty else { return 0 }
        return Double(completedExercises) / Double(workout.exercises.count)
    }

    /// Top working-set weight from the user's most recent prior session
    /// of the same exercise — used for the per-row comparison delta.
    private func lastSessionTopSet(for exercise: Exercise) -> ExerciseSet? {
        let prior = allExercises
            .filter { other in
                other.persistentModelID != exercise.persistentModelID
                && other.name.lowercased() == exercise.name.lowercased()
                && !other.sets.isEmpty
                && (other.workout?.endTime != nil)
            }
            .sorted { ($0.workout?.date ?? .distantPast) > ($1.workout?.date ?? .distantPast) }
        guard let last = prior.first else { return nil }
        let working = last.sets.filter { !$0.isWarmUp && $0.weight > 0 }
        return working.max(by: { $0.weight < $1.weight })
    }

    /// Human-readable comparison vs last session for the row badge.
    /// Returns nil if no comparison is available, the current set is empty,
    /// or the change is negligible.
    private func progressBadge(for exercise: Exercise) -> WorkoutExerciseRow.Badge? {
        let working = exercise.sets.filter { !$0.isWarmUp && $0.weight > 0 }
        guard let currentTop = working.max(by: { $0.weight < $1.weight }) else { return nil }
        guard let lastTop = lastSessionTopSet(for: exercise) else {
            return .init(text: "New", color: .blue)
        }

        // Weight first — biggest signal
        let weightDelta = currentTop.weight - lastTop.weight
        if weightDelta >= 0.1 {
            return .init(text: "↑ \(weightUnit.formatShort(weightDelta))", color: .green)
        }
        if weightDelta <= -0.1 {
            return .init(text: "↓ \(weightUnit.formatShort(abs(weightDelta)))", color: .orange)
        }
        // Same weight — compare reps at that weight
        let currentRepsAtTop = working.filter { abs($0.weight - currentTop.weight) < 0.01 }.map(\.reps).max() ?? 0
        let lastRepsAtTop    = lastTop.reps
        if currentRepsAtTop > lastRepsAtTop {
            return .init(
                text: "↑ +\(currentRepsAtTop - lastRepsAtTop) rep\(currentRepsAtTop - lastRepsAtTop == 1 ? "" : "s")",
                color: .green
            )
        }
        return nil
    }

    // MARK: - Gym Dock helpers

    /// Which exercise the dock should show. Heuristic: the last exercise (by
    /// the user's chosen order) that has at least one logged set — i.e. the
    /// one they're most likely currently working on. Falls back to the first
    /// exercise if nothing's been logged yet.
    private var activeDockExercise: Exercise? {
        guard !workout.exercises.isEmpty else { return nil }
        let ordered = sortedExercises
        return ordered.last(where: { !$0.sets.isEmpty }) ?? ordered.first
    }

    /// The most recent working set on the given exercise — preferred source for
    /// the "+1 Set" replication. Falls back to any set (warm-up or otherwise)
    /// if no working sets exist yet.
    private func lastWorkingSet(for exercise: Exercise) -> ExerciseSet? {
        exercise.sets.last(where: { !$0.isWarmUp }) ?? exercise.sets.last
    }

    /// The next-set suggestion for the dock, derived from `SuggestedSetEngine`.
    /// Returns nil for cardio exercises so the dock falls back to its
    /// last-set summary (progression doesn't apply to cardio sets).
    private func suggestionForDock(_ exercise: Exercise) -> SuggestedSet? {
        if let last = lastWorkingSet(for: exercise), last.isCardio { return nil }
        let history = allExercises.filter { $0.name == exercise.name }
        return SuggestedSetEngine.suggestNextSet(for: exercise, history: history)
    }

    /// Apply the dock's "+1 Set" action. Uses `SuggestedSetEngine` to pick
    /// values that respect progression (add weight/rep/deload) when there's
    /// enough history; falls back to repeating the last in-session set
    /// otherwise. Returns nothing — does nothing if no history exists.
    private func quickAddSet(for exercise: Exercise) {
        // Cardio exercises: progression doesn't apply meaningfully — keep the
        // existing "copy the last set" behaviour.
        if let last = lastWorkingSet(for: exercise), last.isCardio {
            replicateSet(template: last, into: exercise)
            return
        }

        let history = allExercises.filter { $0.name == exercise.name }
        guard let suggestion = SuggestedSetEngine.suggestNextSet(for: exercise, history: history)
        else { return }

        let newSet = ExerciseSet(
            reps: suggestion.reps,
            weight: suggestion.weight,
            isWarmUp: suggestion.isWarmUp,
            exercise: exercise
        )
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            modelContext.insert(newSet)
            exercise.sets.append(newSet)
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Pure-replication helper used for cardio sets, where progression isn't
    /// applicable. Copies distance/duration as well as reps/weight.
    private func replicateSet(template: ExerciseSet, into exercise: Exercise) {
        let newSet = ExerciseSet(
            reps: template.reps,
            weight: template.weight,
            distance: template.distance,
            durationSeconds: template.durationSeconds,
            exercise: exercise
        )
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            modelContext.insert(newSet)
            exercise.sets.append(newSet)
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: - Computed

    private func averageRPE(for exercise: Exercise) -> Double? {
        let rpes = exercise.sets.filter { !$0.isWarmUp }.compactMap(\.rpe)
        guard !rpes.isEmpty else { return nil }
        return Double(rpes.reduce(0, +)) / Double(rpes.count)
    }

    private func exerciseAccessibilityLabel(_ exercise: Exercise) -> String {
        var parts = [exercise.name]
        let workingSets = exercise.sets.filter { !$0.isWarmUp }
        let warmUps = exercise.sets.filter(\.isWarmUp)
        if !workingSets.isEmpty { parts.append("\(workingSets.count) working sets") }
        if !warmUps.isEmpty { parts.append("\(warmUps.count) warm-up sets") }
        if exercise.supersetGroup != nil { parts.append("superset") }
        return parts.joined(separator: ", ")
    }

    private var sortedExercises: [Exercise] {
        workout.exercises.sorted { $0.order < $1.order }
    }

    private func addExercise() {
        let name = newExerciseName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let exercise = Exercise(name: name, workout: workout, category: newExerciseCategory)
        exercise.order = (workout.exercises.map(\.order).max() ?? -1) + 1
        modelContext.insert(exercise)
        workout.exercises.append(exercise)
        newExerciseName = ""
        newExerciseCategory = .other
        showingSuggestions = false
    }

    private func autoSelectCategory() {
        let trimmed = newExerciseName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if let previous = allExercises.first(where: { $0.name == trimmed && $0.category != nil }) {
            newExerciseCategory = previous.category!
        }
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        var sorted = sortedExercises
        sorted.move(fromOffsets: source, toOffset: destination)
        for (index, exercise) in sorted.enumerated() {
            exercise.order = index
        }
    }

    private func saveAsTemplate() {
        let template = Workout(name: workout.name, isTemplate: true)
        modelContext.insert(template)
        template.copyExercises(from: workout.exercises, into: modelContext)
        showTemplateSaved = true
    }

    private func duplicateWorkout() {
        let newWorkout = Workout(name: workout.name, date: .now)
        modelContext.insert(newWorkout)
        newWorkout.copyExercises(from: workout.exercises, into: modelContext)
        HapticsManager.success()
    }

    /// "Apply" tapped on the Today's-Plan banner. Performs the same
    /// edits previewed in the confirmation dialog (delete overworked-
    /// group exercises that have no logged sets, drop one trailing
    /// blank working set per remaining exercise when intensity is
    /// light) then auto-dismisses the banner.
    private func applyPlanAdjustments(_ plan: TodayPlan) {
        _ = TodayPlanApply.apply(plan: plan, to: workout, in: modelContext)
        modelContext.saveOrLog()
        withAnimation { planAdjustmentsDismissed = true }
    }

    // MARK: - Substitutions card view

    /// One card per substitution suggestion — soft alternative to the
    /// avoid-group removal in the existing adjustments banner. The
    /// user picks Swap (commits the rename via
    /// `TodayPlanApply.applySubstitution`) or Keep (dismisses just
    /// this suggestion; others stay visible).
    private func substitutionsCard(_ suggestions: [TodayPlanApply.SubstitutionSuggestion]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.Signal.caution)
                Text(String(
                    localized: "Suggested swaps",
                    comment: "Section header above the substitution suggestions"
                ))
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)
            }

            VStack(spacing: 10) {
                ForEach(suggestions, id: \.exercise.persistentModelID) { suggestion in
                    substitutionRow(suggestion)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }

    private func substitutionRow(_ suggestion: TodayPlanApply.SubstitutionSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.exercise.name)
                        .font(.subheadline.weight(.semibold))
                        .strikethrough()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right")
                            .font(.caption2.bold())
                            .foregroundStyle(.tertiary)
                        Text(suggestion.suggestedName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                Button {
                    HapticsManager.success()
                    withAnimation {
                        TodayPlanApply.applySubstitution(suggestion, in: modelContext)
                        modelContext.saveOrLog()
                        // No need to dismiss — once the rename
                        // commits, the next render's
                        // `substitutionsFor` won't match this
                        // (now-renamed) exercise to the original key.
                    }
                } label: {
                    Text(String(localized: "Swap", comment: "Action accepting the substitution suggestion"))
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(AppTheme.Signal.caution)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation {
                        // Discard the (inserted, member) tuple Set.insert
                        // returns so the closure's inferred type is Void.
                        _ = dismissedSubstitutions.insert(suggestion.exercise.persistentModelID)
                    }
                } label: {
                    Text(String(localized: "Keep", comment: "Action dismissing a single substitution suggestion"))
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Live Activity

    private func startLiveActivityIfNeeded() {
        guard !workout.isFinished, !workout.isTemplate else { return }
        let manager = WorkoutActivityManager.shared
        if !manager.isActive {
            manager.startActivity(workoutName: workout.name)
        }
        updateLiveActivity()
    }

    private func updateLiveActivity() {
        let manager = WorkoutActivityManager.shared
        let totalSets = workout.exercises.reduce(0) { $0 + $1.sets.count }
        let currentExercise = sortedExercises.last?.name ?? workout.name
        manager.updateActivity(
            exerciseCount: workout.exercises.count,
            setCount: totalSets,
            currentExercise: currentExercise
        )
    }

    // MARK: - Duration Timer

    private func startDurationTimer() {
        guard !workout.isFinished, !workout.isTemplate else { return }
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            updateElapsedTime()
        }
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }

    private func updateElapsedTime() {
        if let duration = workout.formattedDuration {
            elapsedTime = duration
        }
    }

    // MARK: - Supersets

    private var nextSupersetGroup: Int {
        let existing = workout.exercises.compactMap(\.supersetGroup)
        return (existing.max() ?? 0) + 1
    }

    private func unlinkSuperset(_ exercise: Exercise) {
        exercise.supersetGroup = nil
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func linkSuperset(_ exercise: Exercise, with partner: Exercise) {
        let group: Int
        if let existingGroup = partner.supersetGroup {
            group = existingGroup
        } else {
            group = nextSupersetGroup
            partner.supersetGroup = group
        }
        exercise.supersetGroup = group
        let partnerOrder = partner.order
        exercise.order = partnerOrder + 1
        for ex in sortedExercises where ex.persistentModelID != exercise.persistentModelID && ex.order > partnerOrder {
            ex.order += 1
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

}
