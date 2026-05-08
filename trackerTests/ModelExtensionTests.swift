import XCTest
@testable import tracker

final class ModelExtensionTests: XCTestCase {

    // MARK: - Workout.totalVolumeKg

    func testTotalVolumeIsZeroForEmptyWorkout() {
        let w = Workout(name: "Empty")
        XCTAssertEqual(w.totalVolumeKg(), 0)
    }

    func testTotalVolumeSumsRepsTimesWeight() {
        let w = Workout(name: "Push")
        let ex = Exercise(name: "Bench", workout: w, category: .chest)
        ex.sets.append(ExerciseSet(reps: 8,  weight: 80, exercise: ex))
        ex.sets.append(ExerciseSet(reps: 5,  weight: 90, exercise: ex))
        w.exercises.append(ex)
        // 8*80 + 5*90 = 640 + 450 = 1090
        XCTAssertEqual(w.totalVolumeKg(), 1090, accuracy: 0.001)
    }

    func testTotalVolumeExcludesWarmUpsByDefault() {
        let w = Workout(name: "Push")
        let ex = Exercise(name: "Bench", workout: w, category: .chest)
        ex.sets.append(ExerciseSet(reps: 12, weight: 40, isWarmUp: true, exercise: ex))   // ignored
        ex.sets.append(ExerciseSet(reps: 8,  weight: 80, exercise: ex))                    // 640
        w.exercises.append(ex)
        XCTAssertEqual(w.totalVolumeKg(), 640, accuracy: 0.001)
    }

    func testTotalVolumeIncludesWarmUpsWhenRequested() {
        let w = Workout(name: "Push")
        let ex = Exercise(name: "Bench", workout: w, category: .chest)
        ex.sets.append(ExerciseSet(reps: 12, weight: 40, isWarmUp: true, exercise: ex))   // 480
        ex.sets.append(ExerciseSet(reps: 8,  weight: 80, exercise: ex))                    // 640
        w.exercises.append(ex)
        XCTAssertEqual(w.totalVolumeKg(excludingWarmUps: false), 1120, accuracy: 0.001)
    }

    // MARK: - Workout.formattedDuration

    func testFormattedDurationNilWhenNoStart() {
        // Templates default to nil start time
        let w = Workout(name: "Empty", isTemplate: true)
        XCTAssertNil(w.formattedDuration)
    }

    func testFormattedDurationMinutesOnly() {
        let w = Workout(name: "Quick")
        let start = Date.now
        w.startTime = start
        w.endTime = start.addingTimeInterval(45 * 60)
        XCTAssertEqual(w.formattedDuration, "45m")
    }

    func testFormattedDurationHoursAndMinutes() {
        let w = Workout(name: "Long")
        let start = Date.now
        w.startTime = start
        w.endTime = start.addingTimeInterval(95 * 60)   // 1h 35m
        XCTAssertEqual(w.formattedDuration, "1h 35m")
    }

    // MARK: - Workout.isFinished

    func testIsFinishedReflectsEndTime() {
        let w = Workout(name: "X")
        XCTAssertFalse(w.isFinished)
        w.endTime = .now
        XCTAssertTrue(w.isFinished)
    }

    // MARK: - ExerciseSet.formattedDuration

    func testExerciseSetDurationNilWhenNoSeconds() {
        let s = ExerciseSet(reps: 0, weight: 0)
        XCTAssertNil(s.formattedDuration)
    }

    func testExerciseSetDurationMinSec() {
        let s = ExerciseSet(reps: 0, weight: 0, durationSeconds: 90)
        XCTAssertEqual(s.formattedDuration, "1:30")
    }

    func testExerciseSetDurationHourMinSec() {
        let s = ExerciseSet(reps: 0, weight: 0, durationSeconds: 3725)
        XCTAssertEqual(s.formattedDuration, "1:02:05")
    }

    // MARK: - ExerciseSet.formattedDistance

    func testExerciseSetDistanceNilWithoutDistance() {
        let s = ExerciseSet(reps: 0, weight: 0)
        XCTAssertNil(s.formattedDistance)
    }

    func testExerciseSetDistanceFormattedKm() {
        let s = ExerciseSet(reps: 0, weight: 0, distance: 5.0)
        XCTAssertEqual(s.formattedDistance, "5.00 km")
    }

    func testExerciseSetDistanceFormattedMiles() {
        // 5 km ≈ 3.11 mi
        let s = ExerciseSet(reps: 0, weight: 0, distance: 5.0)
        let formatted = s.formattedDistance(unit: .mi)
        XCTAssertNotNil(formatted)
        XCTAssertTrue(formatted?.hasSuffix(" mi") ?? false)
    }

    // MARK: - ExerciseSet.isCardio

    func testIsCardioWhenDistancePresent() {
        let s = ExerciseSet(reps: 0, weight: 0, distance: 5.0)
        XCTAssertTrue(s.isCardio)
    }

    func testIsCardioWhenDurationPresent() {
        let s = ExerciseSet(reps: 0, weight: 0, durationSeconds: 600)
        XCTAssertTrue(s.isCardio)
    }

    func testNotCardioWhenWeightAndRepsOnly() {
        let s = ExerciseSet(reps: 8, weight: 80)
        XCTAssertFalse(s.isCardio)
    }
}
