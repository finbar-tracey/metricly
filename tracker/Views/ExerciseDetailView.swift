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
    @State private var showProgression = true
    @State private var showQuickLog = true
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
    @State private var timerEndDate: Date?

    // Toolbar sheets
    @State private var showRestTimer = false

    // Cardio input
    @State private var newDistance: Double = 5.0
    @State private var newDurationMinutes: Int = 30
    @State private var newDurationSeconds: Int = 0

    var body: some View {
        List {
            if let lastSession = previousSession, !lastSession.sets.isEmpty {
                Section(isExpanded: $showQuickLog) {
                    ForEach(Array(lastSession.sets.enumerated()), id: \.offset) { index, prevSet in
                        quickAddRow(index: index, prevSet: prevSet)
                    }
                } header: {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("Quick Log")
                        Spacer()
                        Image(systemName: showQuickLog ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .font(.subheadline)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation {
                            showQuickLog.toggle()
                        }
                    }
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
                            GradientProgressBar(value: progress, color: .accentColor, height: 8)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            if let rec = progressionRecommendation {
                Section(isExpanded: $showProgression) {
                    ProgressionBannerView(recommendation: rec)
                } header: {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                        Text("Progression")
                    }
                    .font(.subheadline)
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
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showRestTimer = true
                } label: {
                    Image(systemName: "stopwatch")
                }
                .accessibilityLabel("Rest Timer")

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

        .navigationDestination(for: FormGuideDestination.self) { dest in
            ExerciseGuideView(exerciseName: dest.exerciseName)
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
        .sheet(isPresented: $showRestTimer) {
            NavigationStack {
                WorkoutTimerView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showRestTimer = false }
                        }
                    }
            }
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
            if !hasPreFilled, let lastSession = previousSession,
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
                    if prevSet.isCardio {
                        Text([prevSet.formattedDistance(unit: weightUnit.distanceUnit), prevSet.formattedDuration].compactMap { $0 }.joined(separator: " in "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(prevSet.reps) reps × \(weightUnit.format(prevSet.weight))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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

            // Set data display
            if exerciseSet.isCardio {
                VStack(alignment: .trailing, spacing: 2) {
                    if let dist = exerciseSet.formattedDistance(unit: weightUnit.distanceUnit) {
                        Text(dist)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                    }
                    if let dur = exerciseSet.formattedDuration {
                        Text(dur)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    if let rpe = exerciseSet.rpe {
                        Text("@\(rpe)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.purple)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.purple.opacity(0.12), in: .capsule)
                    }
                }
            } else {
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

    private var isCardioExercise: Bool {
        exercise.category == .cardio
    }

    private var newSetSection: some View {
        Section {
            if isCardioExercise {
                cardioInputFields
            } else {
                strengthInputFields
            }

            // RPE picker (shared)
            if !newIsWarmUp || isCardioExercise {
                rpePicker
            }

            // Add button
            Button {
                addSet()
            } label: {
                Label(
                    isCardioExercise ? "Add Entry" : (newIsWarmUp ? "Add Warm-up" : "Add Set"),
                    systemImage: "plus.circle.fill"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    newIsWarmUp
                        ? AnyShapeStyle(LinearGradient(colors: [.orange, Color(red: 0.9, green: 0.5, blue: 0.1)], startPoint: .leading, endPoint: .trailing))
                        : AnyShapeStyle(LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: (newIsWarmUp ? Color.orange : Color.accentColor).opacity(0.30), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
        } header: {
            SectionHeader(title: "New Set", icon: "plus.circle.fill", color: .accentColor)
        }
    }

    @ViewBuilder
    private var cardioInputFields: some View {
        // Distance
        HStack {
            Label {
                Text("Distance")
                    .font(.subheadline)
            } icon: {
                Image(systemName: "point.bottomleft.forward.to.point.topright.scurvepath")
                    .foregroundStyle(Color.accentColor)
            }
            Spacer()
            Button {
                newDistance = max(0.1, newDistance - weightUnit.distanceUnit.stepSize)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            Text(String(format: "%.1f %@", newDistance, weightUnit.distanceUnit.label))
                .font(.system(.body, design: .rounded, weight: .bold))
                .monospacedDigit()
                .frame(minWidth: 80)
            Button {
                newDistance += weightUnit.distanceUnit.stepSize
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
        }

        // Duration
        HStack {
            Label {
                Text("Duration")
                    .font(.subheadline)
            } icon: {
                Image(systemName: "stopwatch")
                    .foregroundStyle(Color.accentColor)
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

    @ViewBuilder
    private var strengthInputFields: some View {
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
    }

    private var rpePicker: some View {
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

    private var timerBar: some View {
        VStack(spacing: 8) {
            GradientProgressBar(
                value: Double(restDuration - restRemaining) / Double(max(1, restDuration)),
                color: restRemaining <= 10 ? .red : .blue,
                height: 6
            )
            .accessibilityLabel("Rest timer: \(restRemaining) seconds remaining")

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

    private var progressionRecommendation: ProgressionRecommendation? {
        let history = allExercises
            .filter { other in
                other.name == exercise.name
                && !(other.workout?.isTemplate ?? true)
                && !other.sets.isEmpty
            }
            .sorted { ($0.workout?.date ?? .distantPast) > ($1.workout?.date ?? .distantPast) }
        let sessions = ProgressionAdvisor.buildSessions(from: history)
        guard sessions.count >= 2 else { return nil }
        let rec = ProgressionAdvisor.recommend(sessions: sessions, muscleGroup: exercise.category)
        if case .insufficient = rec.action { return nil }
        return rec
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
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { t in
            guard let endDate = timerEndDate else {
                t.invalidate()
                return
            }
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
        if !isWarmUp && historicalBestWeight > 0 && weight > historicalBestWeight && !alreadyBeaten {
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
        }
    }

    private func quickLog(from source: ExerciseSet) {
        let newSet = ExerciseSet(
            reps: source.reps,
            weight: source.weight,
            distance: source.distance,
            durationSeconds: source.durationSeconds,
            exercise: exercise
        )
        withAnimation(.spring(duration: 0.3)) {
            modelContext.insert(newSet)
            exercise.sets.append(newSet)
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if !source.isCardio {
            checkForPR(weight: source.weight, isWarmUp: false)
        }
        showUndoSnackbar(for: newSet)
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

