import SwiftUI

extension ExerciseDetailView {

    @ToolbarContentBuilder
    var exerciseToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Done") { isWeightFieldFocused = false }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                if session.restTimer.timerActive { session.restTimer.stop() } else { session.restTimer.start() }
            } label: {
                Image(systemName: session.restTimer.timerActive ? "stopwatch.fill" : "stopwatch")
                    .symbolEffect(.pulse, isActive: session.restTimer.timerActive)
            }
            .accessibilityLabel(session.restTimer.timerActive ? "Stop rest timer" : "Start rest timer")

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
                    session.editedName = exercise.name
                    session.isEditingName = true
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                Button { session.showingRestEditor = true } label: {
                    Label(restMenuLabel, systemImage: "timer")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("Exercise options")
        }
    }

    @ViewBuilder
    var exerciseBottomInset: some View {
        VStack(spacing: 0) {
            if session.showUndo {
                UndoBar(
                    icon: "arrow.uturn.backward.circle.fill",
                    message: "Set added",
                    color: .blue,
                    onUndo: undoLastSet
                )
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Set added. Undo available.")
            }
            if session.restTimer.timerActive {
                ExerciseRestTimerBar(controller: session.restTimer)
            }
        }
    }
}
