import SwiftUI
import SwiftData
import UIKit

extension ExerciseDetailView {

    func isPR(_ exerciseSet: ExerciseSet) -> Bool {
        guard !exerciseSet.isWarmUp,
              historicalBestWeight > 0,
              exerciseSet.weight > historicalBestWeight else { return false }
        for s in exercise.sets {
            if s.persistentModelID == exerciseSet.persistentModelID { return true }
            if !s.isWarmUp && s.weight > historicalBestWeight { return false }
        }
        return false
    }

    func warmUpCountBefore(_ index: Int) -> Int {
        exercise.sets.prefix(index).filter(\.isWarmUp).count
    }

    func showUndoSnackbar(for set: ExerciseSet) {
        session.lastAddedSet = set
        session.undoWorkItem?.cancel()
        withAnimation(.easeInOut(duration: 0.25)) {
            session.showUndo = true
        }
        let work = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.25)) {
                session.showUndo = false
            }
            session.lastAddedSet = nil
        }
        session.undoWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
    }

    func undoLastSet() {
        guard let setToRemove = session.lastAddedSet else { return }
        exercise.sets.removeAll { $0.persistentModelID == setToRemove.persistentModelID }
        modelContext.delete(setToRemove)
        session.lastAddedSet = nil
        session.undoWorkItem?.cancel()
        withAnimation(.easeInOut(duration: 0.25)) {
            session.showUndo = false
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func checkForPR(weight: Double, isWarmUp: Bool) {
        let alreadyBeaten = exercise.sets.dropLast().contains { !$0.isWarmUp && $0.weight > historicalBestWeight }
        guard !isWarmUp && historicalBestWeight > 0 && weight > historicalBestWeight && !alreadyBeaten else { return }

        session.prWeight = weight
        let goal = liftGoals.first {
            $0.exerciseName.lowercased() == exercise.name.lowercased()
            && $0.achievedDate == nil
            && weight >= $0.targetWeight
        }
        if let goal {
            goal.achievedDate = .now
            session.goalTarget = goal.targetWeight
        }

        guard celebrationsEnabled else { return }

        if goal != nil {
            withAnimation(.spring(duration: 0.5, bounce: 0.3)) {
                session.showGoalBanner = true
                session.goalScale = 1.15
            }
        } else {
            withAnimation(.spring(duration: 0.5, bounce: 0.3)) {
                session.showPRBanner = true
                session.prScale = 1.15
            }
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(duration: 0.3)) {
                session.prScale = 1.0
                session.goalScale = 1.0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation(.easeOut(duration: 0.4)) {
                session.showPRBanner = false
                session.showGoalBanner = false
            }
        }
    }

    func addSet() {
        if isCardioExercise {
            let totalSeconds = session.newDurationMinutes * 60 + session.newDurationSeconds
            let distanceKm = weightUnit.distanceUnit.toKm(session.newDistance)
            let exerciseSet = ExerciseSet(
                rpe: session.newRPE,
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
            let weightInKg = weightUnit.toKg(session.newWeight)
            let exerciseSet = ExerciseSet(
                reps: session.newReps,
                weight: weightInKg,
                isWarmUp: session.newIsWarmUp,
                rpe: session.newIsWarmUp ? nil : session.newRPE,
                exercise: exercise
            )
            withAnimation(.spring(duration: 0.3)) {
                modelContext.insert(exerciseSet)
                exercise.sets.append(exerciseSet)
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            checkForPR(weight: weightInKg, isWarmUp: session.newIsWarmUp)
            showUndoSnackbar(for: exerciseSet)
            if !session.newIsWarmUp && (settingsArray.first?.autoStartRestTimer ?? false) {
                session.restTimer.start()
            }
        }
    }

    func duplicateSet(_ source: ExerciseSet) {
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

    func deleteSets(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(exercise.sets[index])
        }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
