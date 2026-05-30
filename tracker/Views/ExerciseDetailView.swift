import SwiftUI
import SwiftData
import UIKit
import UserNotifications
import AudioToolbox

struct ExerciseDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.weightUnit) private var weightUnit
    @Environment(\.scenePhase) private var scenePhase
    @Query private var allExercises: [Exercise]
    @Query private var settingsArray: [UserSettings]
    @Query private var liftGoals: [LiftGoal]
    let exercise: Exercise

    init(exercise: Exercise) {
        self.exercise = exercise
        let name = exercise.name
        _allExercises = Query(filter: #Predicate<Exercise> { $0.name == name })
    }

    @State private var newReps = 10
    @State private var newWeight = 20.0
    @State private var newIsWarmUp = false
    @State private var newRPE: Int? = nil
    @State private var editingSet: ExerciseSet?
    @State private var editReps = 10
    @State private var editWeight = 20.0
    /// Persistent ID of the set currently being inline-edited within the row.
    /// Tap a set → enter inline edit mode. Long-press → full sheet (existing).
    @State private var inlineEditingSetID: PersistentIdentifier?
    @State private var isEditingName = false
    @State private var showingRestEditor = false
    @State private var editedName = ""
    @State private var hasPreFilled = false
    @State private var showPRBanner = false
    @State private var prScale = 1.0
    @State private var prWeight: Double = 0
    @State private var showGoalBanner = false
    @State private var goalScale = 1.0
    @State private var goalTarget: Double = 0
    /// User's master switch for celebration moments (Settings → Workout).
    @AppStorage("celebrationsEnabled") private var celebrationsEnabled = true
    @State private var lastAddedSet: ExerciseSet?
    @State private var showUndo = false
    @State private var undoWorkItem: DispatchWorkItem?

    @FocusState private var isWeightFieldFocused: Bool

    // Rest timer
    @State private var restDuration = 90
    @State private var hasLoadedSettings = false
    @State private var restRemaining = 0
    @State private var timerActive = false
    @State private var timer: Timer?
    @State private var timerEndDate: Date?

    @State private var showRPE = false

    // Cardio input
    @State private var newDistance: Double = 5.0
    @State private var newDurationMinutes: Int = 30
    @State private var newDurationSeconds: Int = 0

    var body: some View {
        List {
            // MARK: - Compact stats strip
            // One thin row instead of: 3-col stats banner + lift goal section
            // + standalone progression section. PR + goal progress live here.
            // Per-set progression suggestions are handled by SuggestedSetPill
            // inline in the new-set composer.
            Section {
                exerciseHeaderStrip
                    .listRowBackground(Color.clear)
                    .listRowInsets(.init(top: 4, leading: 16, bottom: 4, trailing: 16))
            }

            // MARK: - Today's Plan exercise-level hint
            if let hint = exercisePlanHint {
                Section {
                    hint
                        .listRowBackground(Color.clear)
                        .listRowInsets(.init(top: 0, leading: 16, bottom: 4, trailing: 16))
                }
            }

            // MARK: - Notes
            Section {
                TextField("Add a note...", text: Binding(
                    get: { exercise.notes },
                    set: { exercise.notes = $0 }
                ), axis: .vertical)
                .lineLimit(2...4)
                .font(.subheadline)
                .listRowBackground(Color(.secondarySystemGroupedBackground))
            } header: {
                SectionHeader(title: "Notes", icon: "note.text", color: .blue)
            }

            // MARK: - Sets
            if exercise.sets.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "repeat")
                            .font(.system(size: 32))
                            .foregroundStyle(.tertiary)
                        Text("No Sets Logged")
                            .font(.subheadline.weight(.semibold))
                        Text("Add a set below to start tracking.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ForEach(Array(exercise.sets.enumerated()), id: \.offset) { index, exerciseSet in
                        setRow(index: index, exerciseSet: exerciseSet)
                            .listRowBackground(setRowBackground(for: exerciseSet))
                    }
                    .onDelete(perform: deleteSets)
                } header: {
                    setsSectionHeader
                }
            }

            newSetSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .overlay(alignment: .top) {
            if showPRBanner {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.Signal.amber, Color(red: 0.85, green: 0.42, blue: 0.10)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 52, height: 52)
                            .shadow(color: AppTheme.Signal.amber.opacity(0.55), radius: 12, y: 4)
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    Text("NEW PERSONAL RECORD")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.9))
                    Text(exercise.name)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                    Text(weightUnit.format(prWeight))
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(colors: AppTheme.Gradients.caution, startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: AppTheme.heroRadius, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.heroRadius, style: .continuous)
                        .stroke(.white.opacity(0.25), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.28), radius: 24, y: 10)
                .scaleEffect(prScale)
                .padding(.top, 12)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .scale(scale: 0.5)).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("New personal record! \(exercise.name), \(weightUnit.format(prWeight))")
            }
        }
        .overlay(alignment: .top) {
            if showGoalBanner {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.Signal.recovery, AppTheme.Signal.recoveryDeep],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 52, height: 52)
                            .shadow(color: AppTheme.Signal.recovery.opacity(0.55), radius: 12, y: 4)
                        Image(systemName: "target")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    Text("GOAL ACHIEVED")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.9))
                    Text(exercise.name)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                    Text("\(weightUnit.format(goalTarget)) reached!")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(colors: AppTheme.Gradients.recovery, startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: AppTheme.heroRadius, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.heroRadius, style: .continuous)
                        .stroke(.white.opacity(0.25), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.28), radius: 24, y: 10)
                .scaleEffect(goalScale)
                .padding(.top, 12)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .scale(scale: 0.5)).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Goal achieved! \(exercise.name), \(weightUnit.format(goalTarget))")
            }
        }
        .navigationTitle(exercise.name)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isWeightFieldFocused = false
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    if timerActive { stopTimer() } else { startTimer() }
                } label: {
                    Image(systemName: timerActive ? "stopwatch.fill" : "stopwatch")
                        .symbolEffect(.pulse, isActive: timerActive)
                }
                .accessibilityLabel(timerActive ? "Stop rest timer" : "Start rest timer")

                NavigationLink(value: PlateCalcDestination()) {
                    Image(systemName: "circle.grid.2x2")
                }
                .accessibilityLabel("Plate Calculator")

                Menu {
                    NavigationLink(value: exercise.name) {
                        Label("History", systemImage: "chart.bar")
                    }
                    NavigationLink(value: FormGuideDestination(exerciseName: exercise.name)) {
                        Label("Form Guide", systemImage: "text.book.closed")
                    }
                    NavigationLink(value: SubstitutionDestination(exerciseName: exercise.name)) {
                        Label("Find Alternatives", systemImage: "arrow.triangle.2.circlepath")
                    }
                    Button {
                        editedName = exercise.name
                        isEditingName = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    Button {
                        showingRestEditor = true
                    } label: {
                        Label(restMenuLabel, systemImage: "timer")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More")
            }
        }
        .navigationDestination(for: FormGuideDestination.self) { dest in
            ExerciseGuideView(exerciseName: dest.exerciseName)
        }
        .navigationDestination(for: SubstitutionDestination.self) { dest in
            ExerciseSubstitutionsView(exerciseName: dest.exerciseName)
        }
        .alert("Edit Exercise", isPresented: $isEditingName) {
            TextField("Name", text: $editedName)
            Button("Save") {
                exercise.name = editedName
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $editingSet) { exerciseSet in
            EditSetSheet(exerciseSet: exerciseSet, reps: editReps, weight: editWeight, distanceUnit: weightUnit.distanceUnit)
        }
        .sheet(isPresented: $showingRestEditor) {
            ExerciseRestEditorSheet(exercise: exercise,
                                    defaultGlobal: settingsArray.first?.defaultRestDuration ?? 90) {
                // After save, also bring the in-view restDuration in sync so
                // the active timer reflects the new value without a re-mount.
                restDuration = exercise.customRestDuration ?? (settingsArray.first?.defaultRestDuration ?? 90)
            }
            .presentationDetents([.medium])
        }
        .navigationDestination(for: PlateCalcDestination.self) { _ in
            PlateCalculatorView()
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                if showUndo {
                    undoBar
                }
                if timerActive {
                    timerBar
                }
            }
        }
        .onAppear {
            if !hasLoadedSettings, let settings = settingsArray.first {
                // Prefer exercise-specific rest duration, then fall back to global
                restDuration = exercise.customRestDuration ?? settings.defaultRestDuration
                hasLoadedSettings = true
            }
            if !hasPreFilled {
                // Strength: prefer the smart suggestion. Falls back to the
                // previous session's first set when there's no engine output.
                if let suggestion = suggestedSet {
                    newReps = suggestion.reps
                    newWeight = weightUnit.display(suggestion.weight)
                    hasPreFilled = true
                } else if let lastSession = previousSession,
                          let firstSet = lastSession.sets.first {
                    if firstSet.isCardio {
                        if let km = firstSet.distance {
                            newDistance = weightUnit.distanceUnit.display(km)
                        }
                        if let secs = firstSet.durationSeconds {
                            newDurationMinutes = secs / 60
                            newDurationSeconds = secs % 60
                        }
                    } else {
                        newReps = firstSet.reps
                        newWeight = weightUnit.display(firstSet.weight)
                    }
                    hasPreFilled = true
                }
            }
        }
        .onDisappear {
            isWeightFieldFocused = false
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            stopTimer()
            cancelRestNotification()
        }
        .scrollDismissesKeyboard(.immediately)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active, let endDate = timerEndDate {
                let remaining = Int(ceil(endDate.timeIntervalSinceNow))
                if remaining <= 0 {
                    timer?.invalidate()
                    timer = nil
                    timerEndDate = nil
                    restRemaining = 0
                    timerActive = false
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    AudioServicesPlayAlertSound(SystemSoundID(1005))
                    cancelRestNotification()
                } else {
                    restRemaining = remaining
                    if timer == nil {
                        startDisplayTimer()
                    }
                }
            }
        }
    }

    private func isPR(_ exerciseSet: ExerciseSet) -> Bool {
        guard !exerciseSet.isWarmUp,
              historicalBestWeight > 0,
              exerciseSet.weight > historicalBestWeight else { return false }
        // Only the first set in this session that exceeds the historical best is a PR
        for s in exercise.sets {
            if s.persistentModelID == exerciseSet.persistentModelID { return true }
            if !s.isWarmUp && s.weight > historicalBestWeight { return false }
        }
        return false
    }

    /// Section header for Sets — combines the count + last-session reference
    /// on a single line. Gives the user "what to beat" without burning a
    /// separate row.
    @ViewBuilder
    private var setsSectionHeader: some View {
        let working = exercise.sets.filter { !$0.isWarmUp }
        let summary = lastSessionSummaryText
        HStack(spacing: 8) {
            Image(systemName: "repeat")
                .font(.caption.bold())
                .foregroundStyle(Color.accentColor)
            Text("\(working.count) Working")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Spacer()
            if let summary {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 10))
                    Text(summary)
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(.tertiary)
            }
        }
        .textCase(nil)   // override List's auto-uppercasing
    }

    /// One-line summary of the user's last session for this exercise — e.g.
    /// "Last: 4 × 8 @ 80 kg". Returns nil if there's no comparable history.
    private var lastSessionSummaryText: String? {
        guard let last = previousSession else { return nil }
        let working = last.sets.filter { !$0.isWarmUp && $0.weight > 0 }
        guard let top = working.max(by: { $0.weight < $1.weight }) else { return nil }
        let count = working.count
        return "Last: \(count) × \(top.reps) @ \(weightUnit.format(top.weight))"
    }

    /// Compact, scannable set row. Tap → inline edit (steppers swap in for
    /// the static reps × weight display). Long-press → full sheet for
    /// warm-up/RPE/duplicate. Cardio sets fall back to the sheet either way
    /// since their inputs (distance/duration) don't fit inline.
    /// Subtle row tint: warm-ups read orange, a fresh PR reads amber, so the
    /// two special set types are distinguishable at a glance mid-set without
    /// dimming the whole row (which made warm-ups muddy).
    @ViewBuilder
    private func setRowBackground(for set: ExerciseSet) -> some View {
        let base = Color(.secondarySystemGroupedBackground)
        if set.isWarmUp {
            ZStack { base; AppTheme.Signal.caution.opacity(0.07) }
        } else if isPR(set) {
            ZStack { base; AppTheme.Signal.amber.opacity(0.08) }
        } else {
            base
        }
    }

    private func setRow(index: Int, exerciseSet: ExerciseSet) -> some View {
        let isEditing = inlineEditingSetID == exerciseSet.persistentModelID
        return Group {
            if isEditing && !exerciseSet.isCardio {
                inlineEditRow(index: index, exerciseSet: exerciseSet)
            } else {
                displayRow(index: index, exerciseSet: exerciseSet)
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                duplicateSet(exerciseSet)
            } label: {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                exerciseSet.isWarmUp.toggle()
                HapticsManager.lightTap()
            } label: {
                Label(exerciseSet.isWarmUp ? "Working" : "Warm-up",
                      systemImage: exerciseSet.isWarmUp ? "flame.fill" : "flame")
            }
            .tint(.orange)
        }
    }

    /// The default compact display row.
    private func displayRow(index: Int, exerciseSet: ExerciseSet) -> some View {
        let setNumber = index + 1 - warmUpCountBefore(index)
        let badgeColor: Color = exerciseSet.isWarmUp ? .orange : .accentColor
        let isPRSet = !exerciseSet.isWarmUp && isPR(exerciseSet)

        return HStack(spacing: 12) {
            indexBadge(badgeColor: badgeColor, setNumber: setNumber, isWarmUp: exerciseSet.isWarmUp)

            if exerciseSet.isCardio {
                cardioSetData(exerciseSet)
            } else {
                // Column-aligned reps / weight so stacked sets line up and
                // scan fast mid-workout. Weight gets equal prominence with
                // the rep count instead of reading as faint secondary text.
                HStack(spacing: 0) {
                    Text("\(exerciseSet.reps)")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(exerciseSet.isWarmUp ? .secondary : .primary)
                        .frame(width: 40, alignment: .trailing)
                    Text("×")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(width: 22, alignment: .center)
                    Text(weightUnit.format(exerciseSet.weight))
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(exerciseSet.isWarmUp ? .secondary : .primary)
                        .frame(minWidth: 80, alignment: .leading)
                }
            }

            Spacer(minLength: 6)

            if let rpe = exerciseSet.rpe {
                Text("RPE \(rpe)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.purple)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.purple.opacity(0.14), in: .capsule)
            }
            if isPRSet {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.Signal.amber)
                    .accessibilityLabel("Personal record")
            }
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onTapGesture {
            // Cardio sets jump straight to the full sheet — distance/duration
            // editing doesn't fit inline.
            if exerciseSet.isCardio {
                editingSet = exerciseSet
                editReps = exerciseSet.reps
                editWeight = weightUnit.display(exerciseSet.weight)
            } else {
                withAnimation(.snappy(duration: 0.20)) {
                    inlineEditingSetID = exerciseSet.persistentModelID
                }
                HapticsManager.lightTap()
            }
        }
        .onLongPressGesture(minimumDuration: 0.4) {
            // Long-press always opens the full sheet for advanced edits.
            editingSet = exerciseSet
            editReps = exerciseSet.reps
            editWeight = weightUnit.display(exerciseSet.weight)
            HapticsManager.lightTap()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(setAccessibilityLabel(index: index, exerciseSet: exerciseSet))
        .accessibilityHint("Tap to edit reps and weight, long press for more")
    }

    /// Inline edit row — compact reps + weight steppers + Done check.
    /// Mutations bind directly to the SwiftData ExerciseSet, so changes
    /// persist immediately as the user taps + or −.
    private func inlineEditRow(index: Int, exerciseSet: ExerciseSet) -> some View {
        let setNumber = index + 1 - warmUpCountBefore(index)
        let badgeColor: Color = exerciseSet.isWarmUp ? .orange : .accentColor
        let displayWeight = weightUnit.display(exerciseSet.weight)

        return VStack(spacing: 6) {
            HStack(spacing: 8) {
                indexBadge(badgeColor: badgeColor, setNumber: setNumber, isWarmUp: exerciseSet.isWarmUp)

                HStack(spacing: 4) {
                    inlineStepButton(systemName: "minus.circle.fill") {
                        exerciseSet.reps = max(1, exerciseSet.reps - 1)
                    }
                    Text("\(exerciseSet.reps)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .frame(minWidth: 22)
                    inlineStepButton(systemName: "plus.circle.fill") {
                        exerciseSet.reps += 1
                    }
                }

                Text("×").font(.caption2).foregroundStyle(.tertiary)

                HStack(spacing: 4) {
                    inlineStepButton(systemName: "minus.circle.fill") {
                        let newDisplay = max(0, displayWeight - weightIncrement)
                        exerciseSet.weight = weightUnit.toKg(newDisplay)
                    }
                    Text(weightUnit.format(exerciseSet.weight))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .frame(minWidth: 64)
                    inlineStepButton(systemName: "plus.circle.fill") {
                        let newDisplay = displayWeight + weightIncrement
                        exerciseSet.weight = weightUnit.toKg(newDisplay)
                    }
                }

                Spacer(minLength: 4)

                // Done — collapses back to the display row
                Button {
                    withAnimation(.snappy(duration: 0.20)) {
                        inlineEditingSetID = nil
                    }
                    HapticsManager.lightTap()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Done editing")
            }

            // Quick RPE row — most common values for working sets, plus a
            // clear-X. Avoids the long-press-then-sheet round trip.
            if !exerciseSet.isWarmUp {
                inlineRPERow(for: exerciseSet)
            }
        }
        .padding(.vertical, 4)
    }

    /// Compact RPE picker shown inside the inline-edit row. Common working-
    /// set values only (6–10) so the row stays readable; rarer values still
    /// available via long-press → full sheet.
    private func inlineRPERow(for exerciseSet: ExerciseSet) -> some View {
        HStack(spacing: 6) {
            Text("RPE")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
            ForEach([6, 7, 8, 9, 10], id: \.self) { value in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    exerciseSet.rpe = (exerciseSet.rpe == value) ? nil : value
                } label: {
                    Text("\(value)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(exerciseSet.rpe == value ? .white : .purple)
                        .frame(width: 26, height: 26)
                        .background(
                            exerciseSet.rpe == value ? Color.purple : Color.purple.opacity(0.12),
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
            // Clear current RPE
            if exerciseSet.rpe != nil {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    exerciseSet.rpe = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear RPE")
            }
        }
        .padding(.leading, 36)   // align with the data column above (past the 28pt badge + spacing)
    }

    private func indexBadge(badgeColor: Color, setNumber: Int, isWarmUp: Bool) -> some View {
        ZStack {
            Circle()
                .fill(badgeColor.opacity(0.18))
                .frame(width: 28, height: 28)
            if isWarmUp {
                Image(systemName: "flame.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.orange)
            } else {
                Text("\(setNumber)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(badgeColor)
            }
        }
    }

    private func inlineStepButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.plain)
        // Generous tap target so sweaty thumbs still hit it
        .frame(minWidth: 34, minHeight: 34)
        .contentShape(Rectangle())
    }

    /// Cardio variant of the set data block — distance + duration.
    @ViewBuilder
    private func cardioSetData(_ exerciseSet: ExerciseSet) -> some View {
        HStack(spacing: 6) {
            if let dist = exerciseSet.formattedDistance(unit: weightUnit.distanceUnit) {
                Text(dist)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            if let dur = exerciseSet.formattedDuration {
                Text(dur)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func setAccessibilityLabel(index: Int, exerciseSet: ExerciseSet) -> String {
        var parts: [String] = []
        if exerciseSet.isWarmUp {
            parts.append("Warm-up set")
        } else {
            parts.append("Set \(index + 1 - warmUpCountBefore(index))")
        }
        parts.append("\(exerciseSet.reps) reps at \(weightUnit.format(exerciseSet.weight))")
        if isPR(exerciseSet) {
            parts.append("Personal record")
        }
        return parts.joined(separator: ", ")
    }

    private var weightIncrement: Double {
        weightUnit == .kg ? 2.5 : 5.0
    }

    private var isCardioExercise: Bool {
        exercise.category == .cardio
    }

    // MARK: - Today's Plan hint (per-exercise)

    /// Shows a small callout if today's plan flagged this exercise's muscle group
    /// as one to "go easy on" or "avoid". Returns nil if no hint applies.
    private var exercisePlanHint: ExercisePlanHintView? {
        guard let cat = exercise.category,
              let plan = TodayPlanStore.load(),
              !plan.alreadyTrainedToday
        else { return nil }

        if plan.avoidGroups.contains(cat) {
            return ExercisePlanHintView(
                tone: .warning,
                icon: "exclamationmark.triangle.fill",
                message: "You've trained \(cat.rawValue.lowercased()) several times this week — consider a different focus today."
            )
        }
        if plan.goEasyOnGroups.contains(cat) {
            return ExercisePlanHintView(
                tone: .caution,
                icon: "leaf.fill",
                message: "\(cat.rawValue) is still recovering — go light, leave 1–2 reps in the tank."
            )
        }
        if plan.intensity == .light {
            return ExercisePlanHintView(
                tone: .info,
                icon: "leaf.fill",
                message: "Today is a lighter session — reduce volume by ~1 set and stop short of failure."
            )
        }
        return nil
    }

    // MARK: - Compact header strip

    /// One-line header: PR pill + active lift-goal pill (if set). Replaces
    /// the old 3-column stats banner + standalone Lift Goal section.
    /// Progression recommendations live inline in `SuggestedSetPill` now.
    @ViewBuilder
    private var exerciseHeaderStrip: some View {
        let prWeight = historicalBestWeight
        let activeGoal = liftGoals.first(where: {
            $0.exerciseName.lowercased() == exercise.name.lowercased() && $0.achievedDate == nil
        })

        HStack(spacing: 8) {
            // PR pill
            if prWeight > 0 {
                statPill(
                    icon: "trophy.fill",
                    iconColor: AppTheme.Signal.amber,
                    label: "PR",
                    value: weightUnit.formatShort(prWeight)
                )
            }

            // Goal pill — shows current progress toward target
            if let goal = activeGoal {
                let currentBest = max(prWeight, exercise.sets.filter { !$0.isWarmUp }.map(\.weight).max() ?? 0)
                let pct = goal.targetWeight > 0 ? min(1.0, currentBest / goal.targetWeight) : 0
                statPill(
                    icon: "target",
                    iconColor: Color.accentColor,
                    label: "Goal",
                    value: "\(weightUnit.formatShort(goal.targetWeight)) · \(Int(pct * 100))%"
                )
            }

            // Category pill — keep for context, smaller than the old banner
            if let cat = exercise.category {
                statPill(
                    icon: cat.icon,
                    iconColor: .purple,
                    label: nil,
                    value: cat.rawValue
                )
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    private func statPill(icon: String, iconColor: Color, label: String?, value: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(iconColor)
            if let label {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .tracking(0.4)
            }
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Color(.tertiarySystemFill), in: Capsule())
    }

    private var newSetSection: some View {
        Section {
            // Suggested-next-set hint — compact pill above the composer row.
            if !isCardioExercise, let s = suggestedSet {
                SuggestedSetPill(suggestion: s) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    newReps = s.reps
                    newWeight = weightUnit.display(s.weight)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 6, trailing: 16))
            }

            if isCardioExercise {
                // Cardio keeps the form-style inputs (different fields).
                cardioInputFields
                rpePicker
                addEntryButton
            } else {
                // Strength: one compact row that visually matches the logged
                // set rows above. Reps / weight steppers + Add inline.
                nextSetRow
                if !newIsWarmUp {
                    rpePicker
                }
            }
        } header: {
            SectionHeader(
                title: newIsWarmUp ? "New Warm-up" : "New Set",
                icon: "plus.circle.fill",
                color: newIsWarmUp ? .orange : .accentColor
            )
        }
    }

    /// "Next row" composer — the strength path. Mirrors the logged-set row
    /// shape so the act of completing a set and starting the next is visually
    /// continuous instead of mode-switching into a form.
    private var nextSetRow: some View {
        let badgeColor: Color = newIsWarmUp ? .orange : .accentColor
        let nextNumber = exercise.sets.filter { !$0.isWarmUp }.count + 1
        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                // Index badge — same shape as logged rows, with a "+" hint when
                // the slot is empty (helps the row read as "the next set").
                ZStack {
                    Circle()
                        .strokeBorder(badgeColor.opacity(0.45),
                                      style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                        .background(Circle().fill(badgeColor.opacity(0.10)))
                        .frame(width: 28, height: 28)
                    if newIsWarmUp {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.orange)
                    } else {
                        Text("\(nextNumber)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(badgeColor)
                    }
                }

                // Reps stepper
                HStack(spacing: 4) {
                    inlineStepButton(systemName: "minus.circle.fill") {
                        newReps = max(1, newReps - 1)
                    }
                    Text("\(newReps)")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .frame(minWidth: 24)
                    inlineStepButton(systemName: "plus.circle.fill") {
                        newReps = min(100, newReps + 1)
                    }
                }

                Text("×").font(.caption2).foregroundStyle(.tertiary)

                // Weight stepper
                HStack(spacing: 4) {
                    inlineStepButton(systemName: "minus.circle.fill") {
                        newWeight = max(0, newWeight - weightIncrement)
                    }
                    Text(weightUnit.format(newWeight))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .frame(minWidth: 64)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isWeightFieldFocused = true
                        }
                        .accessibilityLabel("Weight: \(weightUnit.format(newWeight))")
                        .overlay {
                            TextField("", value: $newWeight, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.center)
                                .focused($isWeightFieldFocused)
                                .opacity(isWeightFieldFocused ? 1 : 0)
                                .frame(width: 64)
                                .onChange(of: newWeight) {
                                    if newWeight < 0 { newWeight = 0 }
                                }
                        }
                    inlineStepButton(systemName: "plus.circle.fill") {
                        newWeight += weightIncrement
                    }
                }

                Spacer(minLength: 4)

                // Add button — small green check, lives in the row
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    addSet()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(newIsWarmUp ? Color.orange : Color.green)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(newIsWarmUp ? "Add warm-up" : "Add set")
            }

            // Tiny footer with the warm-up toggle — easy to flip without
            // dominating the row.
            HStack(spacing: 6) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    newIsWarmUp.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: newIsWarmUp ? "flame.fill" : "flame")
                            .font(.caption2.bold())
                        Text(newIsWarmUp ? "Warm-up" : "Mark as warm-up")
                            .font(.caption2)
                    }
                    .foregroundStyle(newIsWarmUp ? .orange : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        (newIsWarmUp ? Color.orange : Color.secondary)
                            .opacity(newIsWarmUp ? 0.16 : 0.08),
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }

    /// The original full-width Add Entry button — still used for cardio
    /// since the cardio composer can't be condensed into one row.
    private var addEntryButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            addSet()
        } label: {
            Label("Add Entry", systemImage: "plus.circle.fill")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Color.accentColor, in: Capsule())
                .foregroundStyle(.white)
        }
        .buttonStyle(.pressableCard)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private var cardioInputFields: some View {
        // Distance
        HStack {
            Label {
                Text("Distance")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            } icon: {
                ZStack {
                    Circle().fill(Color.accentColor.opacity(0.16)).frame(width: 28, height: 28)
                    Image(systemName: "point.bottomleft.forward.to.point.topright.scurvepath")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            Spacer()
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                newDistance = max(0.1, newDistance - weightUnit.distanceUnit.stepSize)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor.opacity(0.8))
            }
            .buttonStyle(.pressableCard)
            Text(String(format: "%.1f %@", newDistance, weightUnit.distanceUnit.label))
                .font(.system(size: 17, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.accentColor)
                .frame(minWidth: 90)
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                newDistance += weightUnit.distanceUnit.stepSize
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.pressableCard)
        }

        // Duration
        HStack {
            Label {
                Text("Duration")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            } icon: {
                ZStack {
                    Circle().fill(Color.accentColor.opacity(0.16)).frame(width: 28, height: 28)
                    Image(systemName: "stopwatch")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            Spacer()
            Picker("Min", selection: $newDurationMinutes) {
                ForEach(0..<181) { m in
                    Text("\(m)m").tag(m)
                }
            }
            .pickerStyle(.menu)
            .fixedSize()
            Picker("Sec", selection: $newDurationSeconds) {
                ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { s in
                    Text("\(s)s").tag(s)
                }
            }
            .pickerStyle(.menu)
            .fixedSize()
        }
    }

    /// Compact RPE picker for the new-set composer. Always visible (no chevron
    /// hiding it), common working-set range only (6–10), matching the inline
    /// edit row's styling for visual consistency across both surfaces.
    private var rpePicker: some View {
        HStack(spacing: 6) {
            Text("RPE")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
            ForEach([6, 7, 8, 9, 10], id: \.self) { value in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    newRPE = (newRPE == value) ? nil : value
                } label: {
                    Text("\(value)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(newRPE == value ? .white : .purple)
                        .frame(width: 26, height: 26)
                        .background(
                            newRPE == value ? Color.purple : Color.purple.opacity(0.12),
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
            if newRPE != nil {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    newRPE = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear RPE")
            }
        }
    }

    private var timerBar: some View {
        VStack(spacing: 10) {
            GradientProgressBar(
                value: Double(restDuration - restRemaining) / Double(max(1, restDuration)),
                color: restRemaining <= 10 ? .red : .blue,
                height: 8
            )
            .accessibilityLabel("Rest timer: \(restRemaining) seconds remaining")

            HStack {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    adjustRest(-15)
                } label: {
                    Text("−15s")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(.thinMaterial, in: .capsule)
                        .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 0.5))
                }
                .buttonStyle(.pressableCard)
                .accessibilityLabel("Subtract 15 seconds")
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    adjustRest(15)
                } label: {
                    Text("+15s")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(.thinMaterial, in: .capsule)
                        .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 0.5))
                }
                .buttonStyle(.pressableCard)
                .accessibilityLabel("Add 15 seconds")

                Spacer()

                Text(timerText)
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(restRemaining <= 10 ? .red : .primary)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: restRemaining)
                    .accessibilityLabel("Rest timer: \(timerText)")

                Spacer()

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    stopTimer()
                } label: {
                    Text("Skip")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(.thinMaterial, in: .capsule)
                        .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 0.5))
                }
                .buttonStyle(.pressableCard)
                .accessibilityLabel("Skip rest timer")
            }

        }
        .padding()
        .background(.thickMaterial)
    }

    private var undoBar: some View {
        UndoBar(icon: "arrow.uturn.backward.circle.fill", message: "Set added", color: .blue, onUndo: undoLastSet)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Set added. Undo available.")
    }

    private func showUndoSnackbar(for set: ExerciseSet) {
        lastAddedSet = set
        undoWorkItem?.cancel()
        withAnimation(.easeInOut(duration: 0.25)) {
            showUndo = true
        }
        let work = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.25)) {
                showUndo = false
            }
            lastAddedSet = nil
        }
        undoWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
    }

    private func undoLastSet() {
        guard let setToRemove = lastAddedSet else { return }
        exercise.sets.removeAll { $0.persistentModelID == setToRemove.persistentModelID }
        modelContext.delete(setToRemove)
        lastAddedSet = nil
        undoWorkItem?.cancel()
        withAnimation(.easeInOut(duration: 0.25)) {
            showUndo = false
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private var historicalBestWeight: Double {
        allExercises
            .filter { other in
                other.name == exercise.name
                && other.persistentModelID != exercise.persistentModelID
                && !(other.workout?.isTemplate ?? true)
            }
            .flatMap(\.sets)
            .filter { !$0.isWarmUp }
            .map(\.weight)
            .max() ?? 0
    }

    /// Concrete next-set suggestion for the new-set composer. Used both to
    /// pre-fill the inputs on first appear and to render the "Suggested" pill.
    private var suggestedSet: SuggestedSet? {
        // Cardio progression doesn't apply, and the input fields are different
        guard !isCardioExercise else { return nil }
        let history = allExercises.filter { $0.name == exercise.name }
        return SuggestedSetEngine.suggestNextSet(for: exercise, history: history)
    }

    /// Menu label that surfaces the current rest setting at a glance. Shows
    /// the per-exercise override if set, otherwise the global default — so
    /// the user knows what they'll change before they tap.
    private var restMenuLabel: String {
        if let secs = exercise.customRestDuration {
            return "Rest: \(secs)s (custom)"
        }
        let global = settingsArray.first?.defaultRestDuration ?? 90
        return "Rest: \(global)s (default)"
    }

    private var previousSession: Exercise? {
        allExercises
            .filter { other in
                other.name == exercise.name
                && other.persistentModelID != exercise.persistentModelID
                && !(other.workout?.isTemplate ?? true)
                && !other.sets.isEmpty
            }
            .sorted { a, b in
                (a.workout?.date ?? .distantPast) > (b.workout?.date ?? .distantPast)
            }
            .first
    }

    private var timerText: String {
        let minutes = restRemaining / 60
        let seconds = restRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private static let restNotificationID = "restTimerComplete"

    private func startTimer() {
        // Stop any existing timer first
        timer?.invalidate()
        timer = nil

        let endDate = Date.now.addingTimeInterval(TimeInterval(restDuration))
        timerEndDate = endDate
        restRemaining = restDuration
        timerActive = true

        scheduleRestNotification(seconds: restDuration)

        startDisplayTimer()
    }

    private func startDisplayTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 0.5, repeats: true) { [self] t in
            guard let endDate = timerEndDate else { t.invalidate(); return }
            let remaining = Int(ceil(endDate.timeIntervalSinceNow))
            if remaining > 0 {
                restRemaining = remaining
            } else {
                t.invalidate()
                timer = nil
                timerEndDate = nil
                restRemaining = 0
                timerActive = false
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                AudioServicesPlayAlertSound(SystemSoundID(1005))
                cancelRestNotification()
            }
        }
        // Add to .common so the timer keeps firing while the user scrolls
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        timerEndDate = nil
        timerActive = false
        cancelRestNotification()
    }

    private func adjustRest(_ amount: Int) {
        if let endDate = timerEndDate {
            timerEndDate = endDate.addingTimeInterval(TimeInterval(amount))
            restRemaining = max(0, Int(ceil(timerEndDate!.timeIntervalSinceNow)))
        } else {
            restRemaining = max(0, restRemaining + amount)
        }
        restDuration = max(15, restDuration + amount)
        if timerActive {
            scheduleRestNotification(seconds: restRemaining)
        }
    }

    private func scheduleRestNotification(seconds: Int) {
        let center = UNUserNotificationCenter.current()

        // Request permission if needed
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }

        // Cancel any existing rest notification
        center.removePendingNotificationRequests(withIdentifiers: [Self.restNotificationID])

        let content = UNMutableNotificationContent()
        content.title = "Rest Complete"
        content.body = "Time to start your next set!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, TimeInterval(seconds)), repeats: false)
        let request = UNNotificationRequest(identifier: Self.restNotificationID, content: content, trigger: trigger)
        center.add(request)
    }

    private func cancelRestNotification() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.restNotificationID])
    }

    private func warmUpCountBefore(_ index: Int) -> Int {
        exercise.sets.prefix(index).filter(\.isWarmUp).count
    }



    private func checkForPR(weight: Double, isWarmUp: Bool) {
        // Only celebrate if this is the first set in the session to exceed the historical best
        let alreadyBeaten = exercise.sets.dropLast().contains { !$0.isWarmUp && $0.weight > historicalBestWeight }
        guard !isWarmUp && historicalBestWeight > 0 && weight > historicalBestWeight && !alreadyBeaten else { return }

        prWeight = weight
        // A deliberate Lift Goal being hit is the bigger moment — its
        // celebration supersedes the generic PR banner.
        let goal = liftGoals.first {
            $0.exerciseName.lowercased() == exercise.name.lowercased()
            && $0.achievedDate == nil
            && weight >= $0.targetWeight
        }
        // Record the goal as achieved regardless — muting celebrations hides
        // the banner, it doesn't un-hit the goal.
        if let goal {
            goal.achievedDate = .now
            goalTarget = goal.targetWeight
        }

        // The visible celebration (banner + haptics) is gated on the
        // user's Celebrations setting; the PR/goal is still recorded above.
        guard celebrationsEnabled else { return }

        if goal != nil {
            withAnimation(.spring(duration: 0.5, bounce: 0.3)) {
                showGoalBanner = true
                goalScale = 1.15
            }
        } else {
            withAnimation(.spring(duration: 0.5, bounce: 0.3)) {
                showPRBanner = true
                prScale = 1.15
            }
        }

        // Double haptic burst for celebration
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
        // Pulse back to normal
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(duration: 0.3)) {
                prScale = 1.0
                goalScale = 1.0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation(.easeOut(duration: 0.4)) {
                showPRBanner = false
                showGoalBanner = false
            }
        }
    }

    private func addSet() {
        if isCardioExercise {
            let totalSeconds = newDurationMinutes * 60 + newDurationSeconds
            let distanceKm = weightUnit.distanceUnit.toKm(newDistance)
            let exerciseSet = ExerciseSet(
                rpe: newRPE,
                distance: distanceKm,
                durationSeconds: totalSeconds > 0 ? totalSeconds : nil,
                exercise: exercise
            )
            withAnimation(.spring(duration: 0.3)) {
                modelContext.insert(exerciseSet)
                exercise.sets.append(exerciseSet)
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showUndoSnackbar(for: exerciseSet)
        } else {
            let weightInKg = weightUnit.toKg(newWeight)
            let exerciseSet = ExerciseSet(
                reps: newReps,
                weight: weightInKg,
                isWarmUp: newIsWarmUp,
                rpe: newIsWarmUp ? nil : newRPE,
                exercise: exercise
            )
            withAnimation(.spring(duration: 0.3)) {
                modelContext.insert(exerciseSet)
                exercise.sets.append(exerciseSet)
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            checkForPR(weight: weightInKg, isWarmUp: newIsWarmUp)
            showUndoSnackbar(for: exerciseSet)
            if !newIsWarmUp && (settingsArray.first?.autoStartRestTimer ?? false) {
                startTimer()
            }
        }
    }

    private func duplicateSet(_ source: ExerciseSet) {
        let newSet = ExerciseSet(
            reps: source.reps,
            weight: source.weight,
            distance: source.distance,
            durationSeconds: source.durationSeconds,
            exercise: exercise
        )
        withAnimation(.spring(duration: 0.3)) {
            modelContext.insert(newSet)
            if let sourceIndex = exercise.sets.firstIndex(where: { $0.persistentModelID == source.persistentModelID }) {
                exercise.sets.insert(newSet, at: exercise.sets.index(after: sourceIndex))
            } else {
                exercise.sets.append(newSet)
            }
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        showUndoSnackbar(for: newSet)
    }

    private func deleteSets(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(exercise.sets[index])
        }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

struct PlateCalcDestination: Hashable {}

#if DEBUG
#Preview("Logging — set rows") {
    let container = try! ModelContainer(
        for: MetriclySchema.schema,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let ctx = container.mainContext

    // Prior session establishes a beatable best (80 kg) so the PR row tints.
    let pastWorkout = Workout(name: "Push", date: .now.addingTimeInterval(-7 * 86400))
    ctx.insert(pastWorkout)
    let pastEx = Exercise(name: "Bench Press", workout: pastWorkout, category: .chest)
    ctx.insert(pastEx)
    pastEx.sets = [ExerciseSet(reps: 8, weight: 80, exercise: pastEx)]

    // Current session: a warm-up plus two working sets — the second a PR (> 80).
    let workout = Workout(name: "Push")
    ctx.insert(workout)
    let exercise = Exercise(name: "Bench Press", workout: workout, category: .chest)
    ctx.insert(exercise)
    exercise.sets = [
        ExerciseSet(reps: 10, weight: 40, isWarmUp: true, exercise: exercise),
        ExerciseSet(reps: 8, weight: 80, rpe: 8, exercise: exercise),
        ExerciseSet(reps: 6, weight: 85, rpe: 9, exercise: exercise),
    ]

    return NavigationStack { ExerciseDetailView(exercise: exercise) }
        .modelContainer(container)
}
#endif

