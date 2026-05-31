import SwiftUI
import SwiftData

/// Mutable UI state for an in-progress exercise logging session.
@Observable
final class ExerciseSessionState {
    var newReps = 10
    var newWeight = 20.0
    var newIsWarmUp = false
    var newRPE: Int?
    var editingSet: ExerciseSet?
    var editReps = 10
    var editWeight = 20.0
    var inlineEditingSetID: PersistentIdentifier?
    var isEditingName = false
    var showingRestEditor = false
    var editedName = ""
    var hasPreFilled = false
    var showPRBanner = false
    var prScale = 1.0
    var prWeight: Double = 0
    var showGoalBanner = false
    var goalScale = 1.0
    var goalTarget: Double = 0
    var lastAddedSet: ExerciseSet?
    var showUndo = false
    var undoWorkItem: DispatchWorkItem?
    var restTimer = RestTimerController()
    var hasLoadedSettings = false
    var showRPE = false
    var newDistance: Double = 5.0
    var newDurationMinutes: Int = 30
    var newDurationSeconds: Int = 0
}
