import SwiftUI
import SwiftData
import UIKit
import UserNotifications
import AudioToolbox

struct ExerciseDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.weightUnit) private var weightUnit
    @Query private var allExercises: [Exercise]
    @Query private var settingsArray: [UserSettings]
    @Query private var liftGoals: [LiftGoal]
    let exercise: Exercise
    @State private var newReps = 10
    @State private var newWeight = 20.0
    @State private var newIsWarmUp = false
    @State private var newRPE: Int? = nil
    @State private var editingSet: ExerciseSet?
    @State private var editReps = 10
    @State private var editWeight = 20.0
    @State private var isEditingName = false
    @State private var editedName = ""
    @State private var loggedPreviousIndices: Set<Int> = []
    @State private var hasPreFilled = false
    @State private var showPRBanner = false
    @State private var prScale = 1.0
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
    @State private var autoStartRest = false
    @State private var showRestPrompt = false

    var body: some View {
        List {
            if let lastSession = previousSession, !lastSession.sets.isEmpty {
                Section {
                    ForEach(Array(lastSession.sets.enumerated()), id: \.offset) { index, prevSet in
                        quickAddRow(index: index, prevSet: prevSet)
                    }
                } header: {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("Quick Log")
                    }
                    .font(.subheadline)
                } footer: {
                    Text("Tap to log each set from your last session.")
                }
            }

            // Goal progress
            if let goal = liftGoals.first(where: { $0.exerciseName.lowercased() == exercise.name.lowercased() && $0.achievedDate == nil }) {
                Section {
                    let pr = historicalBestWeight
                    let currentBest = max(pr, exercise.sets.filter { !$0.isWarmUp }.map(\.weight).max() ?? 0)
                    let progress = goal.targetWeight > 0 ? min(1.0, currentBest / goal.targetWeight) : 0
                    HStack(spacing: 12) {
                        Image(systemName: "target")
                            .font(.title3)
                            .foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Goal: \(weightUnit.format(goal.targetWeight))")
                                .font(.subheadline.weight(.semibold))
                            Text("Current best: \(weightUnit.format(currentBest)) (\(Int(progress * 100))%)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ProgressView(value: progress)
                                .tint(Color.accentColor)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                TextField("Add a note...", text: Binding(
                    get: { exercise.notes },
                    set: { exercise.notes = $0 }
                ), axis: .vertical)
                    .lineLimit(2...4)
                    .font(.subheadline)
            } header: {
                Text("Notes")
            }

            if exercise.sets.isEmpty {
                ContentUnavailableView {
                    Label("No Sets", systemImage: "repeat")
                } description: {
                    Text("Add a set below to start tracking.")
                }
                .listRowBackground(Color(.systemGroupedBackground))
            }

            ForEach(Array(exercise.sets.enumerated()), id: \.offset) { index, exerciseSet in
                setRow(index: index, exerciseSet: exerciseSet)
            }
            .onDelete(perform: deleteSets)

            newSetSection
        }
        .overlay(alignment: .top) {
            if showPRBanner {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                    Text("New Personal Record!")
                    Image(systemName: "trophy.fill")
                }
                .font(.subheadline.bold())
                .foregroundStyle(.black)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.yellow.gradient, in: .capsule)
                .shadow(color: .yellow.opacity(0.4), radius: 12, y: 4)
                .scaleEffect(prScale)
                .padding(.top, 8)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .scale(scale: 0.5)).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
                .accessibilityLabel("New personal record achieved")
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
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    NavigationLink(value: exercise.name) {
                        Label("History", systemImage: "chart.bar")
                    }
                    NavigationLink(value: SubstitutionsDestination(exerciseName: exercise.name)) {
                        Label("Substitutions", systemImage: "arrow.triangle.2.circlepath")
                    }
                    Button {
                        editedName = exercise.name
                        isEditingName = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .navigationDestination(for: String.self) { name in
            ExerciseHistoryView(exerciseName: name)
        }
        .navigationDestination(for: SubstitutionsDestination.self) { dest in
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
            EditSetSheet(exerciseSet: exerciseSet, reps: editReps, weight: editWeight)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                if showUndo {
                    undoBar
                }
                if timerActive {
                    timerBar
                } else if showRestPrompt {
                    restPromptBar
                }
            }
        }
        .onAppear {
            if !hasLoadedSettings, let settings = settingsArray.first {
                // Prefer exercise-specific rest duration, then fall back to global
                restDuration = exercise.customRestDuration ?? settings.defaultRestDuration
                autoStartRest = settings.autoStartRestTimer
                hasLoadedSettings = true
            }
            if !hasPreFilled, let lastSession = previousSession,
               let firstSet = lastSession.sets.first {
                newReps = firstSet.reps
                newWeight = weightUnit.display(firstSet.weight)
                hasPreFilled = true
            }
        }
        .onDisappear {
            stopTimer()
            cancelRestNotification()
        }
    }

    @ViewBuilder
    private func quickAddRow(index: Int, prevSet: ExerciseSet) -> some View {
        let isLogged = loggedPreviousIndices.contains(index)
        Button {
            if !isLogged {
                quickLog(from: prevSet)
                loggedPreviousIndices.insert(index)
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isLogged ? Color.green.opacity(0.15) : Color.accentColor.opacity(0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: isLogged ? "checkmark" : "arrow.turn.down.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isLogged ? .green : Color.accentColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Set \(index + 1)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isLogged ? .secondary : .primary)
                    Text("\(prevSet.reps) reps × \(weightUnit.format(prevSet.weight))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isLogged {
                    Text("Logged")
                        .font(.caption2.bold())
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.green.opacity(0.1), in: .capsule)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .disabled(isLogged)
        .accessibilityLabel(isLogged ? "Set \(index + 1), logged, \(prevSet.reps) reps at \(weightUnit.format(prevSet.weight))" : "Quick log set \(index + 1), \(prevSet.reps) reps at \(weightUnit.format(prevSet.weight))")
        .accessibilityHint(isLogged ? "" : "Double tap to log this set")
    }

    private func isPR(_ exerciseSet: ExerciseSet) -> Bool {
        !exerciseSet.isWarmUp
        && historicalBestWeight > 0
        && exerciseSet.weight > historicalBestWeight
    }

    @ViewBuilder
    private func setRow(index: Int, exerciseSet: ExerciseSet) -> some View {
        let setNumber = index + 1 - warmUpCountBefore(index)
        HStack(spacing: 12) {
            // Set number badge
            ZStack {
                Circle()
                    .fill(exerciseSet.isWarmUp ? .orange.opacity(0.15) : Color.accentColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                if exerciseSet.isWarmUp {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.orange)
                } else {
                    Text("\(setNumber)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.accentColor)
                }
            }

            // Labels
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(exerciseSet.isWarmUp ? "Warm-up" : "Set \(setNumber)")
                        .font(.subheadline.weight(.semibold))
                    if isPR(exerciseSet) {
                        HStack(spacing: 3) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 9))
                            Text("PR")
                                .font(.caption2.bold())
                        }
                        .foregroundStyle(.yellow)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.yellow.opacity(0.15), in: .capsule)
                    }
                }
                Text("Tap to edit")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Reps × Weight + RPE
            HStack(spacing: 4) {
                Text("\(exerciseSet.reps)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(exerciseSet.isWarmUp ? .secondary : .primary)
                Text("×")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text(weightUnit.format(exerciseSet.weight))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                if let rpe = exerciseSet.rpe {
                    Text("@\(rpe)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.purple)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.purple.opacity(0.12), in: .capsule)
                }
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            editingSet = exerciseSet
            editReps = exerciseSet.reps
            editWeight = weightUnit.display(exerciseSet.weight)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(setAccessibilityLabel(index: index, exerciseSet: exerciseSet))
        .accessibilityHint("Double tap to edit")
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

    private var newSetSection: some View {
        Section {
            // Rest timer config
            HStack {
                Label {
                    Text("Rest")
                        .font(.subheadline)
                } icon: {
                    Image(systemName: "timer")
                        .foregroundStyle(Color.accentColor)
                }
                Spacer()
                Stepper("\(restDuration)s", value: $restDuration, in: 15...300, step: 15)
                    .fixedSize()
                if exercise.customRestDuration != restDuration {
                    Button {
                        exercise.customRestDuration = restDuration
                        HapticsManager.lightTap()
                    } label: {
                        Text("Save")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor, in: .capsule)
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Save rest duration for this exercise")
                }
            }

            // Reps row
            HStack {
                Label {
                    Text("Reps")
                        .font(.subheadline)
                } icon: {
                    Image(systemName: "repeat")
                        .foregroundStyle(Color.accentColor)
                }
                Spacer()
                Stepper {
                    Text("\(newReps)")
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .monospacedDigit()
                } onIncrement: {
                    newReps = min(100, newReps + 1)
                } onDecrement: {
                    newReps = max(1, newReps - 1)
                }
                .fixedSize()
            }

            // Weight row
            HStack {
                Label {
                    Text("Weight")
                        .font(.subheadline)
                } icon: {
                    Image(systemName: "scalemass.fill")
                        .foregroundStyle(Color.accentColor)
                }
                Spacer()
                Button {
                    newWeight = max(0, newWeight - weightIncrement)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Decrease weight by \(weightUnit.formatShort(weightIncrement))")
                Text(weightUnit.format(newWeight))
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .frame(minWidth: 80)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isWeightFieldFocused = true
                    }
                    .accessibilityLabel("Weight: \(weightUnit.format(newWeight))")
                    .accessibilityHint("Double tap to type a custom weight")
                    .overlay {
                        TextField("", value: $newWeight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .focused($isWeightFieldFocused)
                            .opacity(isWeightFieldFocused ? 1 : 0)
                            .frame(width: 80)
                            .onChange(of: newWeight) {
                                if newWeight < 0 { newWeight = 0 }
                            }
                    }
                Button {
                    newWeight += weightIncrement
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Increase weight by \(weightUnit.formatShort(weightIncrement))")
            }

            // Warm-up toggle
            Toggle(isOn: $newIsWarmUp) {
                Label {
                    Text("Warm-up Set")
                        .font(.subheadline)
                } icon: {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                }
            }

            // RPE picker
            if !newIsWarmUp {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label {
                            Text("RPE")
                                .font(.subheadline)
                        } icon: {
                            Image(systemName: "gauge.with.needle")
                                .foregroundStyle(.purple)
                        }
                        Spacer()
                        if newRPE != nil {
                            Button("Clear") {
                                newRPE = nil
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    HStack(spacing: 6) {
                        ForEach(1...10, id: \.self) { value in
                            Button {
                                newRPE = value
                            } label: {
                                Text("\(value)")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(newRPE == value ? Color.accentColor : Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                                    .foregroundStyle(newRPE == value ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text("Rate of Perceived Exertion (optional)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            // Add button
            Button {
                addSet()
            } label: {
                HStack {
                    Spacer()
                    Label(newIsWarmUp ? "Add Warm-up" : "Add Set", systemImage: "plus.circle.fill")
                        .font(.headline)
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        } header: {
            HStack {
                Image(systemName: "plus.square.fill")
                    .foregroundStyle(Color.accentColor)
                Text("New Set")
            }
        }
    }

    private var timerBar: some View {
        VStack(spacing: 8) {
            ProgressView(value: Double(restDuration - restRemaining), total: Double(restDuration))
                .tint(restRemaining <= 10 ? .red : .blue)
                .accessibilityLabel("Rest timer progress")
                .accessibilityValue("\(restRemaining) seconds remaining")

            HStack {
                Button {
                    adjustRest(-15)
                } label: {
                    Text("-15s")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: .capsule)
                }
                .accessibilityLabel("Subtract 15 seconds")
                Button {
                    adjustRest(15)
                } label: {
                    Text("+15s")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: .capsule)
                }
                .accessibilityLabel("Add 15 seconds")

                Spacer()

                Text(timerText)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(restRemaining <= 10 ? .red : .primary)
                    .accessibilityLabel("Rest timer: \(timerText)")

                Spacer()

                Button {
                    stopTimer()
                } label: {
                    Text("Skip")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: .capsule)
                }
                .accessibilityLabel("Skip rest timer")
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.regularMaterial)
    }

    private var restPromptBar: some View {
        HStack {
            Button {
                startTimer()
            } label: {
                HStack {
                    Image(systemName: "timer")
                    Text("Start Rest (\(restDuration)s)")
                }
                .font(.subheadline.bold())
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.accentColor, in: .capsule)
                .foregroundStyle(.white)
            }
            .accessibilityLabel("Start \(restDuration) second rest timer")
            Spacer()
            Button {
                showRestPrompt = false
            } label: {
                Text("Dismiss")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: .capsule)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss rest prompt")
        }
        .padding()
        .background(.regularMaterial)
    }

    private var undoBar: some View {
        HStack {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .foregroundStyle(.blue)
            Text("Set added")
                .font(.subheadline)
            Spacer()
            Button {
                undoLastSet()
            } label: {
                Text("Undo")
                    .font(.subheadline.bold())
                    .foregroundStyle(.blue)
            }
            .accessibilityLabel("Undo last set")
            .accessibilityHint("Removes the set you just added")
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .transition(.move(edge: .bottom).combined(with: .opacity))
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

        restRemaining = restDuration
        timerActive = true
        showRestPrompt = false

        scheduleRestNotification(seconds: restDuration)

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            if restRemaining > 1 {
                restRemaining -= 1
            } else {
                // Timer complete — invalidate immediately to prevent re-entry
                t.invalidate()
                timer = nil
                restRemaining = 0
                timerActive = false
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                AudioServicesPlayAlertSound(SystemSoundID(1005))
                cancelRestNotification()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        timerActive = false
        showRestPrompt = false
        cancelRestNotification()
    }

    private func adjustRest(_ amount: Int) {
        restRemaining = max(0, restRemaining + amount)
        restDuration = max(15, restDuration + amount)
        // Reschedule notification with updated time
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

    private func triggerRestTimer() {
        if autoStartRest {
            startTimer()
        } else {
            showRestPrompt = true
        }
    }

    private func checkForPR(weight: Double, isWarmUp: Bool) {
        if !isWarmUp && historicalBestWeight > 0 && weight > historicalBestWeight {
            withAnimation(.spring(duration: 0.5, bounce: 0.3)) {
                showPRBanner = true
                prScale = 1.15
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
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                withAnimation(.easeOut(duration: 0.4)) {
                    showPRBanner = false
                }
            }

            // Check if this PR achieves a lift goal
            if let goal = liftGoals.first(where: {
                $0.exerciseName.lowercased() == exercise.name.lowercased()
                && $0.achievedDate == nil
                && weight >= $0.targetWeight
            }) {
                goal.achievedDate = .now
            }
        }
    }

    private func addSet() {
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
        if !newIsWarmUp {
            triggerRestTimer()
        }
    }

    private func quickLog(from source: ExerciseSet) {
        let newSet = ExerciseSet(
            reps: source.reps,
            weight: source.weight,
            exercise: exercise
        )
        withAnimation(.spring(duration: 0.3)) {
            modelContext.insert(newSet)
            exercise.sets.append(newSet)
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        checkForPR(weight: source.weight, isWarmUp: false)
        showUndoSnackbar(for: newSet)
        triggerRestTimer()
    }

    private func duplicateSet(_ source: ExerciseSet) {
        let newSet = ExerciseSet(
            reps: source.reps,
            weight: source.weight,
            exercise: exercise
        )
        withAnimation(.spring(duration: 0.3)) {
            modelContext.insert(newSet)
            exercise.sets.append(newSet)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        showUndoSnackbar(for: newSet)
        triggerRestTimer()
    }

    private func deleteSets(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(exercise.sets[index])
        }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

struct SubstitutionsDestination: Hashable {
    let exerciseName: String
}
