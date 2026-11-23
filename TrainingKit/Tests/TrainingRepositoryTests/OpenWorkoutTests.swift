import Foundation
import SwiftData
import Testing
import TrainingDomain
import TrainingRepositories

struct OpenWorkoutTests {
    @Test func completePersistsFailureWithoutCountAndStartsTheApplicableRest() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        func reopen() -> CoordinatedModelStore { CoordinatedModelStore(trainingDirectory: directory) }

        let store = reopen()
        let gymID = try #require(store.createGym(name: "Gym").activeGymID)
        let gym = try #require(try store.gymCatalog().gyms.first)
        let equipment = try #require(gym.genericEquipment.first { $0.kind == .dumbbell })
        let load = ExerciseLoad(amount: 12.5, unit: .kg, representation: .perImplement, implementCount: 1)
        var curl = ExercisePrescription(name: "Curl", segments: [.toFailure])
        curl.load = .estimated(load)
        curl.equipmentID = equipment.id
        curl.station = "A7"
        curl.instructions = "Slow lowering"
        curl.restBetweenSets = 45
        curl.restAfterExercise = 90
        var row = ExercisePrescription(name: "Row", sets: 1, segments: [.repetitions(10)])
        row.perSide = true
        let day = RoutineDay(name: "Day", exercises: [curl, row])
        var routine = ManualRoutine(gymID: gymID)
        routine.plan = RoutinePlan(name: "Routine", days: [day], defaultSets: 2)
        try store.saveRoutine(routine)
        let cycle = try store.currentCycle(for: routine.id)

        let id = UUID()
        func command(_ action: SessionCommand.Action, at seconds: TimeInterval) throws {
            _ = try reopen().apply(SessionCommand(sessionID: id, action: action), clock: SetClock(seconds))
        }
        try command(.start(routineID: routine.id, gymID: gymID, dayID: day.id, cycleID: cycle.id), at: 10)

        func completeDisplayedSet(at seconds: TimeInterval) throws -> SessionCommand.Action {
            let workout = try #require(try reopen().openWorkout())
            let set = try #require(workout.nextSet)
            let action = SessionCommand.Action.completeSet(
                exerciseID: set.exercise.id, number: set.number, performance: .init(asPrescribed: set.exercise))
            try command(action, at: seconds)
            return action
        }

        let started = try #require(try reopen().openWorkout())
        #expect(started.id == id)
        #expect(started.rest == nil)
        let first = try #require(started.nextSet)
        #expect(first.exercise.station == "A7" && first.exercise.instructions == "Slow lowering")
        #expect(first.exercise.segments == [.toFailure] && first.exercise.load == .estimated(load))
        #expect(first.equipment == equipment && first.equipment?.isGeneric(in: gymID) == true)
        #expect(first.number == 1 && first.count == 2)

        let firstCompletion = try completeDisplayedSet(at: 20)
        try command(firstCompletion, at: 30)
        let afterFirst = try #require(try reopen().openWorkout())
        #expect(afterFirst.nextSet?.exercise.id == curl.id && afterFirst.nextSet?.number == 2)
        #expect(afterFirst.rest?.completedSetNumber == 1 && afterFirst.rest?.betweenExercises == false)
        #expect(afterFirst.rest?.endsAt == SetClock(65).now)

        let rest = try #require(afterFirst.rest)
        var corrected = rest.performance
        corrected.segments = [.repetitions(12)]
        try command(.correctSet(id: rest.id, performance: corrected), at: 35)
        #expect(try reopen().openWorkout()?.rest?.endsAt == rest.endsAt)
        #expect(try reopen().activeRoutine()?.plan == routine.plan)
        _ = try completeDisplayedSet(at: 75)
        let afterSecond = try #require(try reopen().openWorkout())
        #expect(afterSecond.nextSet?.exercise.id == row.id && afterSecond.nextSet?.number == 1)
        #expect(afterSecond.rest?.completedSetNumber == 2 && afterSecond.rest?.betweenExercises == true)
        #expect(afterSecond.rest?.endsAt == SetClock(165).now)

        _ = try completeDisplayedSet(at: 170)
        let completed = try #require(try reopen().openWorkout())
        #expect(completed.nextSet == nil && completed.rest == nil)
        try reopen().withContext { context in
            let sets = try context.fetch(FetchDescriptor<TrainingSchemaV1.PerformedSet>())
            let failureSets = sets.filter { $0.exerciseID == curl.id }
            #expect(failureSets.map(\.number).sorted() == [1, 2])
            for set in failureSets {
                #expect(
                    try set.performance
                        == (set.number == 1 ? corrected : SetPerformance(segments: [.toFailure], load: load)))
            }
            let rowSet = try #require(sets.first { $0.exerciseID == row.id })
            #expect(try rowSet.performance == SetPerformance(segments: [.repetitions(10)], perSide: true))
        }
    }
}

private struct SetClock: WorkoutClock {
    let now: Date

    init(_ seconds: TimeInterval) {
        now = Date(timeIntervalSinceReferenceDate: seconds)
    }
}
