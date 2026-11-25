import Foundation
import SwiftData
import Testing
import TrainingDomain
import TrainingRepositories

struct OpenWorkoutTests {
    @Test func restAdjustmentsPersistOnlyForTheCurrentSet() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        func reopen() -> CoordinatedModelStore { CoordinatedModelStore(trainingDirectory: directory) }

        let gymID = try #require(reopen().createGym(name: "Gym").activeGymID)
        let row = ExercisePrescription(name: "Row", sets: 3, segments: [.repetitions(10)])
        let curl = ExercisePrescription(name: "Curl", sets: 1, segments: [.repetitions(8)])
        let day = RoutineDay(name: "Day", exercises: [row, curl])
        var routine = ManualRoutine(gymID: gymID)
        routine.plan = RoutinePlan(name: "Routine", days: [day])
        try reopen().saveRoutine(routine)

        let sessionID = UUID()
        func command(_ action: SessionCommand.Action, at seconds: TimeInterval) throws {
            _ = try reopen().apply(SessionCommand(sessionID: sessionID, action: action), clock: SetClock(seconds))
        }
        func rest() throws -> OpenWorkout.Rest {
            try #require(try reopen().openWorkout()?.rest)
        }
        func completeRowSet(_ number: Int, at seconds: TimeInterval) throws {
            try command(.logSet(exerciseID: row.id, number: number, performance: .init(asPrescribed: row)), at: seconds)
        }
        try command(.start(routineID: routine.id, gymID: gymID, dayID: day.id, cycleID: nil), at: 0)
        try completeRowSet(1, at: 10)
        let first = try rest()
        #expect(first.endsAt == SetClock(115).now)
        try command(.adjustRest(setID: first.id, adjustment: .extend), at: 20)
        #expect(try rest().endsAt == SetClock(130).now)
        try command(.adjustRest(setID: first.id, adjustment: .shorten), at: 120)
        #expect(try rest().endsAt == SetClock(120).now)
        #expect(throws: SessionCommandError.restUnavailable) {
            try command(.adjustRest(setID: first.id, adjustment: .extend), at: 121)
        }

        try completeRowSet(2, at: 125)
        let second = try rest()
        #expect(second.endsAt == SetClock(230).now)
        #expect(throws: SessionCommandError.restUnavailable) {
            try command(.adjustRest(setID: first.id, adjustment: .end), at: 130)
        }
        try command(.adjustRest(setID: second.id, adjustment: .end), at: 135)
        #expect(try rest().endsAt == SetClock(135).now)

        try completeRowSet(3, at: 140)
        let afterExercise = try rest()
        #expect(afterExercise.betweenExercises)
        #expect(afterExercise.endsAt == SetClock(275).now)
        #expect(try reopen().activeRoutine()?.plan == routine.plan)
    }

    @Test func supersetRestSettingsApplyToRoundBoundariesAndSurviveRoutineCopy() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CoordinatedModelStore(trainingDirectory: directory)

        let gymID = try #require(store.createGym(name: "Gym").activeGymID)
        let supersetID = UUID()
        var row = ExercisePrescription(name: "Row", sets: 2, segments: [.repetitions(10)])
        var curl = ExercisePrescription(name: "Curl", sets: 2, segments: [.seconds(30)])
        var plank = ExercisePrescription(name: "Plank", sets: 2, segments: [.seconds(5)])
        row.supersetID = supersetID
        curl.supersetID = supersetID
        plank.supersetID = supersetID
        let squat = ExercisePrescription(name: "Squat", sets: 1, segments: [.repetitions(8)])
        let settings = SupersetRest(restBetweenRounds: 40, restAfterSuperset: 70)
        let day = RoutineDay(name: "Day", exercises: [row, squat, curl, plank], supersetRests: [supersetID: settings])
        var routine = ManualRoutine(gymID: gymID)
        routine.plan = RoutinePlan(name: "Routine", days: [day])
        try store.saveRoutine(routine)

        let copy = try #require(routine.plan.copiedForNewRoutine().days.first)
        let copiedSuperset = try #require(copy.exercises.first?.supersetID)
        #expect(copiedSuperset != supersetID)
        #expect(copy.supersetRests == [copiedSuperset: settings])

        let sessionID = UUID()
        func command(_ action: SessionCommand.Action, at seconds: TimeInterval) throws {
            _ = try store.apply(SessionCommand(sessionID: sessionID, action: action), clock: SetClock(seconds))
        }
        func log(_ exercise: ExercisePrescription, _ number: Int, at seconds: TimeInterval) throws {
            try command(
                .logSet(exerciseID: exercise.id, number: number, performance: .init(asPrescribed: exercise)),
                at: seconds)
        }
        try command(.start(routineID: routine.id, gymID: gymID, dayID: day.id, cycleID: nil), at: 0)
        try log(row, 1, at: 5)
        #expect(try store.openWorkout()?.nextSet?.exercise.id == curl.id)
        #expect(try store.openWorkout()?.rest == nil)
        #expect(throws: SessionCommandError.invalidSetNumber) { try log(row, 2, at: 6) }
        try command(.controlTimer(exerciseID: curl.id, number: 1, expectedRevision: 0, action: .start), at: 10)
        let midRound = try #require(try store.openWorkout(clock: SetClock(11)))
        #expect(midRound.timingCues.map(\.kind) == [.holdStarted, .setCompleted])
        #expect(midRound.timingCues.map(\.date) == [13, 43].map { SetClock($0).now })
        let waiting = try #require(try store.openWorkout(clock: SetClock(43)))
        #expect(waiting.nextSet?.exercise.id == plank.id && waiting.timer == nil && waiting.rest == nil)
        try command(.controlTimer(exerciseID: plank.id, number: 1, expectedRevision: 0, action: .start), at: 50)
        let lastMember = try #require(try store.openWorkout(clock: SetClock(51)))
        #expect(lastMember.timingCues.map(\.kind) == [.holdStarted, .setCompleted, .restCompleted])
        #expect(lastMember.timingCues.map(\.date) == [53, 58, 98].map { SetClock($0).now })
        let roundEnd = try #require(try store.openWorkout(clock: SetClock(58)))
        #expect(roundEnd.nextSet?.exercise.id == row.id && roundEnd.nextSet?.number == 2)
        #expect(roundEnd.timer == nil && roundEnd.rest?.endsAt == SetClock(98).now)
        try log(row, 2, at: 100)
        #expect(try store.openWorkout()?.nextSet?.exercise.id == curl.id)
        #expect(try store.openWorkout()?.rest == nil)
        try log(curl, 2, at: 110)
        try log(plank, 2, at: 120)
        #expect(try store.openWorkout()?.rest?.endsAt == SetClock(190).now)
        #expect(try store.openWorkout()?.rest?.betweenExercises == true)
    }

    @Test(arguments: [(false, false), (true, false), (true, true)])
    func sessionSupersetEditsKeepScopeAndPerformedSetsAfterReopening(createAsUsual: Bool, dissolveAsUsual: Bool) throws
    {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        func reopen() -> CoordinatedModelStore { CoordinatedModelStore(trainingDirectory: directory) }
        let gymID = try #require(reopen().createGym(name: "Gym").activeGymID)
        var row = ExercisePrescription(name: "Row", sets: 4, segments: [.repetitions(8)])
        row.group = "Back"
        var press = ExercisePrescription(name: "Press", sets: 2, segments: [.toFailure])
        press.group = "Chest"
        let day = RoutineDay(name: "Day", exercises: [row, press])
        var routine = ManualRoutine(gymID: gymID)
        routine.plan = RoutinePlan(name: "Routine", days: [day])
        let group = UUID()
        var invalid = routine
        invalid.plan.days[0].exercises[0].supersetID = group
        invalid.plan.days[0].exercises[1].supersetID = group
        #expect(throws: SupersetError.incompatibleSetCounts) { try reopen().saveRoutine(invalid) }
        try reopen().saveRoutine(routine)
        let session = UUID()
        func apply(_ action: SessionCommand.Action, at time: TimeInterval) throws {
            let command = SessionCommand(sessionID: session, action: action)
            _ = try reopen().apply(command, clock: SetClock(time))
        }
        func recordNext(_ exercise: ExercisePrescription, _ number: Int, at time: TimeInterval) throws {
            let next = try #require(try reopen().openWorkout(clock: SetClock(time))?.nextSet)
            #expect(next.exercise.id == exercise.id && next.number == number)
            try apply(
                .logSet(
                    exerciseID: next.exercise.id, number: next.number, performance: .init(asPrescribed: next.exercise)),
                at: time)
        }
        try apply(.start(routineID: routine.id, gymID: gymID, dayID: day.id, cycleID: nil), at: 0)
        try recordNext(row, 1, at: 1)
        try recordNext(row, 2, at: 120)
        func creation(rounds: Int) -> SessionCommand {
            let edit = SupersetEdit.create(id: group, members: [row.id, press.id], rounds: rounds, rest: .init())
            return SessionCommand(sessionID: session, action: .editSuperset(edit, saveAsUsual: createAsUsual))
        }
        #expect(throws: SupersetError.incompatibleSetCounts) {
            try reopen().apply(creation(rounds: 1), clock: SetClock(121))
        }
        let create = creation(rounds: 3)
        #expect(try reopen().apply(create, clock: SetClock(122)) == .applied)
        #expect(try reopen().apply(create, clock: SetClock(123)) == .alreadyApplied)
        let grouped = try #require(try reopen().openWorkout())
        #expect(grouped.prescription.day.exercises.map(\.sets) == [3, 3])
        #expect(grouped.prescription.day.exercises.map(\.group) == ["Back", "Chest"])
        let usual = try #require(try reopen().activeRoutine()?.plan.days.first)
        #expect(usual == (createAsUsual ? grouped.prescription.day : day))
        #expect(grouped.nextSupersetRound?.number == 1 && grouped.nextSupersetRound?.count == 3)
        try recordNext(row, 3, at: 240)
        #expect(try reopen().openWorkout()?.rest == nil)
        #expect(try reopen().openWorkout()?.nextSupersetRound?.number == 1)
        try recordNext(press, 1, at: 241)
        #expect(try reopen().openWorkout()?.rest?.endsAt == SetClock(346).now)
        #expect(try reopen().openWorkout()?.nextSupersetRound?.number == 2)
        var expectedUsual = usual
        if createAsUsual {
            try apply(.editSuperset(.dissolve(id: group), saveAsUsual: dissolveAsUsual), at: 242)
            let independent = try #require(try reopen().openWorkout())
            #expect(independent.prescription.day.exercises.allSatisfy { $0.supersetID == nil })
            if dissolveAsUsual { expectedUsual = independent.prescription.day }
        }
        try recordNext(press, 2, at: 550)
        #expect(try reopen().openWorkout()?.rest?.endsAt == SetClock(655).now)
        try recordNext(press, 3, at: 700)
        let summary = try reopen().workoutSummary(id: session)
        #expect(!summary.partial && summary.exercises.map { $0.sets.map(\.number) } == [[1, 2, 3], [1, 2, 3]])
        let final = try #require(try reopen().activeRoutine()?.plan.days.first)
        #expect(final == expectedUsual)
    }

    @Test func previousSupersetSnapshotKeepsItsRoundNumbers() throws {
        let url = try #require(
            Bundle.module.url(
                forResource: "before-remaining-superset-rounds", withExtension: "json", subdirectory: "Fixtures"))
        let snapshot = try JSONDecoder().decode(SessionPrescription.self, from: Data(contentsOf: url))
        let row = try #require(snapshot.day.exercises.first)
        let press = try #require(snapshot.day.exercises.last)
        let id = try #require(row.supersetID)
        #expect(snapshot.roundCount(in: id) == 3)
        #expect(snapshot.roundNumber(for: row, set: 3) == 3)
        #expect(snapshot.restDuration(after: row, completedSet: 1, before: press, nextSet: 1) == 0)
        #expect(snapshot.restDuration(after: press, completedSet: 1, before: row, nextSet: 2) == 105)
    }

    @Test(arguments: [false, true])
    func reopeningAfterRestLeavesTheNextSetWaiting(betweenExercises: Bool) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        func reopen() -> CoordinatedModelStore { CoordinatedModelStore(trainingDirectory: directory) }

        let gymID = try #require(reopen().createGym(name: "Gym").activeGymID)
        let row = ExercisePrescription(name: "Row", sets: betweenExercises ? 1 : 2, segments: [.seconds(10)])
        let curl = ExercisePrescription(name: "Curl", sets: 1, segments: [.seconds(8)])
        let day = RoutineDay(name: "Day", exercises: [row, curl])
        var routine = ManualRoutine(gymID: gymID)
        routine.plan = RoutinePlan(name: "Routine", days: [day], restBetweenSets: 30, restBetweenExercises: 45)
        try reopen().saveRoutine(routine)

        let sessionID = UUID()
        func command(_ action: SessionCommand.Action, at seconds: TimeInterval) throws {
            _ = try reopen().apply(SessionCommand(sessionID: sessionID, action: action), clock: SetClock(seconds))
        }
        try command(.start(routineID: routine.id, gymID: gymID, dayID: day.id, cycleID: nil), at: 0)
        try command(.logSet(exerciseID: row.id, number: 1, performance: .init(asPrescribed: row)), at: 10)

        let active = try #require(try reopen().openWorkout())
        let deadline = betweenExercises ? 55.0 : 40.0
        #expect(active.activeRest(at: SetClock(deadline - 1).now)?.endsAt == SetClock(deadline).now)

        let reopened = try #require(try reopen().openWorkout())
        #expect(reopened.activeRest(at: SetClock(deadline).now) == nil)
        #expect(reopened.activeRest(at: SetClock(3_600).now) == nil)
        let next = try #require(reopened.nextSet)
        #expect(next.exercise.id == (betweenExercises ? curl.id : row.id))
        #expect(next.number == (betweenExercises ? 1 : 2))
        try reopen().withContext { context in
            let count = try context.fetchCount(FetchDescriptor<TrainingSchemaV1.PerformedSet>())
            #expect(count == 1)
        }
        try command(
            .logSet(exerciseID: next.exercise.id, number: next.number, performance: .init(asPrescribed: next.exercise)),
            at: 3_601)
        try reopen().withContext { context in
            let count = try context.fetchCount(FetchDescriptor<TrainingSchemaV1.PerformedSet>())
            #expect(count == 2)
        }
    }

    @Test func occupiedStationAndReplacementsRespectSessionScope() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CoordinatedModelStore(trainingDirectory: directory)
        let gym = try #require(store.createGym(name: "Gym").activeGymID)
        func exercise(_ name: String) -> ExercisePrescription {
            ExercisePrescription(name: name, sets: 2, segments: [.repetitions(10)])
        }
        var squat = exercise("Squat")
        squat.group = "Pierna"
        let walk = exercise("Walk")
        var lunge = exercise("Lunge")
        lunge.group = "Pierna"
        let day = RoutineDay(name: "Day", exercises: [squat, walk, lunge])
        var routine = ManualRoutine(gymID: gym)
        routine.plan = RoutinePlan(name: "Plan", days: [day])
        try store.saveRoutine(routine)
        let id = UUID()
        func apply(_ action: SessionCommand.Action) throws {
            _ = try store.apply(SessionCommand(sessionID: id, action: action), clock: SetClock(10))
        }
        try apply(.start(routineID: routine.id, gymID: gym, dayID: day.id, cycleID: nil))
        #expect(try store.openWorkout()?.pendingExercises == day.exercises)
        try apply(.moveExercise(id: squat.id, toFront: false))
        #expect(try store.openWorkout()?.nextSet?.exercise == walk)
        try apply(.completeSet(exerciseID: walk.id, number: 1, performance: .init(asPrescribed: walk)))
        try apply(.moveExercise(id: squat.id, toFront: true))
        #expect(try store.openWorkout()?.nextSet?.exercise == squat)
        try apply(.skip(exerciseID: squat.id))
        #expect(try store.openWorkout()?.nextSet?.number == 2)
        try apply(.insertExercise(sourceID: squat.id, replacing: nil, saveAsUsual: false))
        try apply(.insertExercise(sourceID: squat.id, replacing: walk.id, saveAsUsual: false))
        #expect(try store.openWorkout()?.pendingExercises.count == 3)
        #expect(try store.activeRoutine()?.plan == routine.plan)
        try apply(.insertExercise(sourceID: walk.id, replacing: lunge.id, saveAsUsual: true))
        let usual = try #require(try store.activeRoutine()?.plan.days.first)
        #expect(usual.exercises.map(\.name) == ["Squat", "Walk", "Walk"])
        #expect(usual.exercises[2].id != walk.id)
    }

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

        try command(
            .adjust(
                exerciseID: curl.id, sets: 2, segments: [.seconds(20), .repetitions(5)], load: curl.load,
                saveAsUsual: false), at: 31)
        #expect(try reopen().openWorkout()?.rest?.prescribedSegments == [.toFailure])
        try command(
            .adjust(exerciseID: curl.id, sets: 2, segments: [.toFailure], load: curl.load, saveAsUsual: false), at: 32)
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

        try command(.logSet(exerciseID: row.id, number: 1, performance: .init(asPrescribed: row)), at: 170)
        #expect(try reopen().openWorkout() == nil)
        let completed = try reopen().workoutSummary(id: id)
        #expect(!completed.partial && completed.finishedAt == SetClock(170).now)
        #expect(completed.exercises[0].sets.map(\.performance.segments) == [[.repetitions(12)], [.toFailure]])
        #expect(try reopen().currentCycle(for: routine.id).id != cycle.id)
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
