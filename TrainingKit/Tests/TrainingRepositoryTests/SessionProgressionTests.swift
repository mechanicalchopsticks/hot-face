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
            var recordedPrevious = fixture.exercise
            recordedPrevious.sets = 1
            var recordedFinal = expected
            recordedFinal.sets = 1
            #expect(try change.previous == recordedPrevious)
            #expect(try change.updated == recordedFinal)
            #expect(try context.fetch(FetchDescriptor<TrainingSchemaV1.Progression>()).first?.balance == 0)
        }
    }

    @Test func acceptingCurrentValuesRecordsOneDecision() throws {
        let f = try Fixture()
        defer { try? FileManager.default.removeItem(at: f.directory) }
        try f.rateEasy()
        try f.rateEasy()
        let offer = try #require(try f.suggestion())
        let load = try #require(f.exercise.load.value)
        func accept() throws {
            try f.store.acceptProgressionSuggestion(
                offer, load: load, repetitions: 10, routineID: f.routine.id, exerciseID: f.exercise.id,
                clock: Fixture.Clock(300))
        }
        try accept()
        #expect(try f.suggestion() == nil)
        #expect(throws: WeightSuggestionError.suggestionChanged) { try accept() }
        let changes = try f.store.prescriptionChanges()
        #expect(changes.count == 1)
        let entry = try #require(changes.first)
        #expect(entry.previous == entry.updated)
        #expect(entry.date == Fixture.Clock(300).now && entry.origin == "suggestion.prepareIncrease")
        let csv = try #require(f.store.exportHistoryCSV().first { $0.name == "changes.csv" })
        #expect(String(decoding: csv.data, as: UTF8.self).components(separatedBy: entry.id.uuidString).count == 3)
    }

    @Test func editorRecordsNewAndRemovedExerciseIDs() throws {
        let f = try Fixture()
        defer { try? FileManager.default.removeItem(at: f.directory) }
        var draft = try #require(try f.store.activeRoutine())
        let newExercise = ExercisePrescription(name: "Press", segments: [.seconds(30)])
        draft.plan.days[0].exercises = [newExercise]
        draft.plan.defaultSets = 4
        try f.store.saveRoutine(draft, at: Fixture.Clock(200).now)
        let csv = try #require(f.store.exportHistoryCSV().first { $0.name == "changes.csv" })
        let text = String(decoding: csv.data, as: UTF8.self)
        #expect(text.contains(",previous,\(f.exercise.id.uuidString),Row,"))
        #expect(text.contains(",final,\(newExercise.id.uuidString),Press,"))
        #expect(!text.contains(",final,\(f.exercise.id.uuidString),Row,"))
        #expect(!text.contains(",previous,\(newExercise.id.uuidString),Press,"))
        let saved = try #require(try f.store.activeRoutine())
        try f.store.saveRoutine(saved)
        let changes = try f.store.prescriptionChanges()
        #expect(changes.count == 2)
        let removal = try #require(changes.first { $0.updated == nil })
        let addition = try #require(changes.first { $0.previous == nil })
        #expect(removal.previous?.id == f.exercise.id && removal.previous?.sets == 1)
        #expect(addition.updated?.id == newExercise.id && addition.updated?.sets == 4)
    }

    @Test func archivedRoutineKeepsDatedChangesAndOriginalSession() throws {
        let f = try Fixture()
        defer { try? FileManager.default.removeItem(at: f.directory) }
        let past = try f.start()
        try f.apply(.logCurrentSet(exerciseID: f.exercise.id, number: 1), to: past)
        var routine = try #require(try f.store.routine(id: f.routine.id))
        let plank = ExercisePrescription(name: "Plank", sets: 2, segments: [.seconds(30)])
        routine.plan.days.append(.init(name: "Other day", exercises: [plank]))
        routine.plan.defaultSets = 3
        routine.plan.days[0].exercises[0].segments = [.seconds(20)]
        try f.store.saveRoutine(routine, at: Fixture.Clock(200).now)
        let current = try f.start()
        let replace = SessionCommand(
            sessionID: current, action: .insertExercise(sourceID: plank.id, replacing: f.exercise.id, saveAsUsual: true)
        )
        #expect(try f.store.apply(replace, clock: Fixture.Clock(300)) == .applied)
        #expect(try f.store.apply(replace, clock: Fixture.Clock(301)) == .alreadyApplied)
        try f.apply(.finish, to: current, at: 310)
        let final = try #require(try f.store.routine(id: routine.id))
        try f.store.archiveRoutine(final)
        let changes = try f.store.prescriptionChanges()
        let additions = changes.filter { $0.previous == nil }
        #expect(additions.count == 1 && additions.first?.updated?.id == plank.id)
        let paired = changes.filter { $0.previous != nil && $0.updated != nil }
        try #require(paired.count == 2)
        #expect(paired.map(\.date) == [Fixture.Clock(300).now, Fixture.Clock(200).now])
        #expect(paired[0].previous?.name == "Row" && paired[0].updated?.name == "Plank")
        #expect(paired[0].previous?.sets == 3 && paired[0].updated?.sets == 2)
        #expect(paired[1].previous?.sets == 1 && paired[1].updated?.sets == 3)
        #expect(paired[1].updated?.segments == [.seconds(20)])
        let history = try f.store.workoutSummary(id: past)
        #expect(history.exercises[0].prescription.sets == 1)
        #expect(history.exercises[0].sets[0].performance.segments == [.repetitions(10)])
    }

    @Test func modeSwitchRejectsStaleOfferAndPreservesAcceptedBridge() throws {
        let fixture = try Fixture(baseline: 50, heavier: 57.5)
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        try fixture.rateEasy()
        try fixture.rateEasy()
        let session = try fixture.start()
        let bridge = try #require(try fixture.suggestion())
        #expect(try fixture.offer(in: session) == .suggested(bridge))
        #expect(throws: WeightSuggestionError.suggestionChanged) {
            try fixture.accept(bridge, in: session, mode: .aggressive)
        }
        #expect(try fixture.store.routine(id: fixture.routine.id)?.plan.days[0].exercises[0] == fixture.exercise)
        #expect(try fixture.offer(in: session) == .suggested(bridge))
        try fixture.accept(bridge, in: session)
        try fixture.apply(.logCurrentSet(exerciseID: fixture.exercise.id, number: 1), to: session)
        try fixture.apply(.rateFinished(exerciseID: fixture.exercise.id, effort: .easy), to: session)
        try fixture.rateEasy()
        let completed = try #require(try fixture.suggestion(mode: .aggressive))
        #expect(completed.reason == .completeBridge && completed.load.amount == 57.5 && completed.repetitions == 10)
        try fixture.accept(completed, mode: .aggressive)
        #expect(try fixture.suggestion(mode: .aggressive) == nil)
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
