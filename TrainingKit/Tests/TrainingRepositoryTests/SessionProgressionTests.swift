import Foundation
import SwiftData
import Testing
import TrainingDomain
import TrainingRepositories

struct SessionProgressionTests {
    @Test func acceptsAggressiveIncreaseInRoutineAndSession() throws {
        let fixture = try Fixture(baseline: 50, heavier: 57.5)
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        try fixture.rateEasy()
        try fixture.rateEasy()
        let session = try fixture.start()
        let increase = try #require(try fixture.suggestion(mode: .aggressive))
        #expect(increase.reason == .higherLoad && increase.load.amount == 57.5 && increase.repetitions == 10)
        #expect(try fixture.offer(in: session, mode: .aggressive) == .suggested(increase))
        try fixture.accept(increase, in: session, mode: .aggressive)
        var expected = fixture.exercise
        expected.load = .confirmed(increase.load)
        #expect(try fixture.store.routine(id: fixture.routine.id)?.plan.days[0].exercises[0] == expected)
        #expect(try fixture.store.openWorkout()?.nextSet?.exercise.load == expected.load)
        try fixture.store.withContext { context in
            let change = try #require(try context.fetch(FetchDescriptor<TrainingSchemaV1.PrescriptionChange>()).first)
            #expect(change.origin == "suggestion.higherLoad")
            #expect(try change.previous == fixture.exercise)
            #expect(try change.updated == expected)
            #expect(try context.fetch(FetchDescriptor<TrainingSchemaV1.Progression>()).first?.balance == 0)
        }
    }

    @Test func changingPerSideClearsBalanceAndRepetitionBridge() throws {
        let fixture = try Fixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        try fixture.rateEasy()
        try fixture.rateEasy()
        let bridge = try #require(try fixture.suggestion())
        #expect(bridge.reason == .prepareIncrease)
        try fixture.accept(bridge)
        try fixture.rateEasy()
        try fixture.rateEasy()
        #expect(try fixture.suggestion()?.reason == .completeBridge)

        var routine = try #require(try fixture.store.routine(id: fixture.routine.id))
        routine.plan.days[0].exercises[0].perSide = true
        try fixture.store.saveRoutine(routine)
        #expect(try fixture.suggestion() == nil)
        try fixture.rateEasy()
        #expect(try fixture.suggestion() == nil)
        try fixture.rateEasy()
        let next = try #require(try fixture.suggestion())
        #expect(next.reason == .prepareIncrease && next.repetitions == 15)
    }

    @Test(arguments: [1, 2])
    func acceptanceKeepsOnlyOutstandingTemporaryAdjustments(temporarySets: Int) throws {
        let fixture = try Fixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let earlier = try fixture.start()
        try fixture.adjust(earlier, sets: 1, reps: 7)
        try fixture.apply(.finish, to: earlier, at: 10)
        try fixture.rateEasy()
        try fixture.rateEasy()

        let current = try fixture.start()
        try fixture.adjust(current, sets: temporarySets, reps: 9)
        let suggestion = try #require(try fixture.suggestion())
        try fixture.accept(suggestion, in: current)
        try fixture.apply(.finish, to: current, at: 200)
        let previous = try #require(
            try fixture.store.previousAdjustment(for: fixture.exercise.id, in: fixture.routine.id))
        #expect(previous.sets == temporarySets)
        #expect(previous.segments == [.repetitions(temporarySets == 1 ? 7 : suggestion.repetitions)])
    }

    @Test func reassigningEquipmentInvalidatesAnOpenSessionOffer() throws {
        let fixture = try Fixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        try fixture.rateEasy()
        try fixture.rateEasy()
        let session = try fixture.start()
        let suggestion = try #require(try fixture.suggestion())
        #expect(try fixture.offer(in: session) == .suggested(suggestion))

        let replacement = EquipmentDescription(name: "Other dumbbell", kind: .dumbbell, unit: .lb)
        _ = try fixture.store.saveEquipment(replacement, in: fixture.routine.gymID)
        var routine = try #require(try fixture.store.routine(id: fixture.routine.id))
        routine.plan.days[0].exercises[0].equipmentID = replacement.id
        try fixture.store.saveRoutine(routine)
        #expect(try fixture.suggestion() == suggestion)
        #expect(try fixture.offer(in: session) == nil)
        #expect(throws: WeightSuggestionError.suggestionChanged) { try fixture.accept(suggestion, in: session) }
        #expect(try fixture.store.openWorkout()?.nextSet?.exercise.equipmentID == fixture.exercise.equipmentID)
        #expect(try fixture.suggestion() == suggestion)
    }

    @Test func sessionOfferRequiresAReadyFirstSetAtTheRequestedTime() throws {
        let fixture = try Fixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        try fixture.rateEasy()
        try fixture.rateEasy()
        let suggestion = try #require(try fixture.suggestion())
        var routine = try #require(try fixture.store.routine(id: fixture.routine.id))
        let warmup = ExercisePrescription(name: "Warmup", sets: 1, segments: [.repetitions(5)])
        routine.plan.days[0].exercises.insert(warmup, at: 0)
        routine.plan.restBetweenExercises = 15
        try fixture.store.saveRoutine(routine)

        let session = try fixture.start()
        #expect(try fixture.offer(in: session) == nil)
        try fixture.apply(.logCurrentSet(exerciseID: warmup.id, number: 1), to: session, at: 90)
        #expect(try fixture.offer(in: session, at: 104) == nil)
        #expect(throws: WeightSuggestionError.suggestionChanged) { try fixture.accept(suggestion, in: session) }
        #expect(try fixture.offer(in: session, at: 105) == .suggested(suggestion))
        try fixture.apply(
            .adjust(
                exerciseID: fixture.exercise.id, sets: 2, segments: [.seconds(30)], load: .undefined,
                saveAsUsual: false), to: session, at: 105)
        try fixture.apply(
            .controlTimer(exerciseID: fixture.exercise.id, number: 1, expectedRevision: 0, action: .start),
            to: session, at: 105)
        #expect(try fixture.offer(in: session, at: 106) == nil)
        try fixture.apply(
            .controlTimer(exerciseID: fixture.exercise.id, number: 1, expectedRevision: 1, action: .complete),
            to: session, at: 120)
        #expect(try fixture.offer(in: session, at: 300) == nil)
        try fixture.apply(.finish, to: session, at: 300)
        #expect(try fixture.offer(in: session, at: 300) == nil)
    }
}

private struct Fixture {
    let directory: URL
    let exercise: ExercisePrescription
    let routine: ManualRoutine
    var store: CoordinatedModelStore { CoordinatedModelStore(trainingDirectory: directory) }

    init(baseline: Decimal = 35, heavier: Decimal = 45) throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = CoordinatedModelStore(trainingDirectory: directory)
        let gym = try #require(try store.createGym(name: "Gym").gyms.first)
        _ = try store.saveInventory([.init(baseline, .lb), .init(heavier, .lb)], for: .dumbbells, in: gym.id)
        var row = ExercisePrescription(name: "Row", segments: [.repetitions(10)])
        row.equipmentID = try #require(gym.genericEquipment.first { $0.kind == .dumbbell }).id
        row.load = .confirmed(.init(amount: baseline, unit: .lb, representation: .perImplement, implementCount: 1))
        exercise = row
        var draft = ManualRoutine(gymID: gym.id)
        draft.plan = RoutinePlan(name: "Plan", days: [.init(name: "Day", exercises: [row])], defaultSets: 1)
        try store.saveRoutine(draft)
        routine = draft
    }

    struct Clock: WorkoutClock {
        let now: Date
        init(_ time: TimeInterval = 100) { now = Date(timeIntervalSinceReferenceDate: time) }
    }

    func apply(_ action: SessionCommand.Action, to session: UUID, at time: TimeInterval = 100) throws {
        _ = try store.apply(.init(sessionID: session, action: action), clock: Clock(time))
    }

    func start() throws -> UUID {
        let session = UUID()
        try apply(
            .start(routineID: routine.id, gymID: routine.gymID, dayID: routine.plan.days[0].id, cycleID: nil),
            to: session, at: 0)
        return session
    }

    func rateEasy() throws {
        let session = try start()
        try apply(.logCurrentSet(exerciseID: exercise.id, number: 1), to: session)
        try apply(.rateFinished(exerciseID: exercise.id, effort: .easy), to: session)
    }

    func adjust(_ session: UUID, sets: Int, reps: Int) throws {
        try apply(
            .adjust(
                exerciseID: exercise.id, sets: sets, segments: [.repetitions(reps)], load: .undefined,
                saveAsUsual: false), to: session, at: 5)
    }

    func suggestion(mode: WeightProgressionMode = .conservative) throws -> WeightSuggestion? {
        try store.suggestedWeightIncrease(routineID: routine.id, exerciseID: exercise.id, mode: mode)
    }

    func offer(in session: UUID, at time: TimeInterval = 100, mode: WeightProgressionMode = .conservative) throws
        -> ProgressionAdvice?
    {
        try store.progressionOffer(
            routineID: routine.id, exerciseID: exercise.id, sessionID: session, clock: Clock(time), mode: mode)?.advice
    }

    func accept(_ suggestion: WeightSuggestion, in session: UUID? = nil, mode: WeightProgressionMode = .conservative)
        throws
    {
        try store.acceptProgressionSuggestion(
            suggestion, load: suggestion.load, repetitions: suggestion.repetitions,
            routineID: routine.id, exerciseID: exercise.id, sessionID: session, clock: Clock(), mode: mode)
    }
}
