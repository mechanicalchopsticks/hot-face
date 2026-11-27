import Foundation
import Testing
import TrainingDomain
import TrainingRepositories

struct WeightSuggestionTests {
    @Test func proposesOnlyReachableIncreasesFromTheUsualPrescription() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        func reopen() -> CoordinatedModelStore { CoordinatedModelStore(trainingDirectory: directory) }
        let gym = try #require(try reopen().createGym(name: "Gym").gyms.first)
        let dumbbell = try #require(gym.genericEquipment.first { $0.kind == .dumbbell })
        var bar = EquipmentDescription(name: "Rack", kind: .barbell, unit: .lb)
        bar.baseWeight = 45
        bar.maximumAddedWeightPerSide = 52.5
        _ = try reopen().saveEquipment(bar, in: gym.id)
        func exercise(_ equipment: EquipmentDescription, _ load: ExerciseLoad, reps: Int) -> ExercisePrescription {
            var usual = ExercisePrescription(name: equipment.name, sets: 1, segments: [.repetitions(reps)])
            usual.equipmentID = equipment.id
            usual.load = .confirmed(load)
            return usual
        }
        func dumbbellLoad(_ amount: Decimal) -> ExerciseLoad {
            .init(amount: amount, unit: .lb, representation: .perImplement, implementCount: 1)
        }
        func barLoad(_ amount: Decimal) -> ExerciseLoad {
            .init(amount: amount, unit: .lb, representation: .includingEquipment, implementCount: 2)
        }
        let curl = exercise(dumbbell, dumbbellLoad(50), reps: 15)
        let row = exercise(dumbbell, dumbbellLoad(50), reps: 10)
        let lightPress = exercise(bar, barLoad(65), reps: 10)
        let empty = exercise(bar, barLoad(45), reps: 8)
        let press = exercise(bar, barLoad(145), reps: 10)
        let maximum = exercise(bar, barLoad(150), reps: 10)
        let exercises = [curl, row, lightPress, empty, press, maximum]
        let day = RoutineDay(name: "Day", exercises: exercises)
        var routine = ManualRoutine(gymID: gym.id)
        routine.plan = RoutinePlan(name: "Plan", days: [day])
        try reopen().saveRoutine(routine)
        func suggestion(_ exercise: ExercisePrescription) throws -> WeightSuggestion? {
            try reopen().suggestedWeightIncrease(routineID: routine.id, exerciseID: exercise.id)
        }
        _ = try reopen().saveInventory([.init(55, .lb), .init(52.5, .lb)], for: .dumbbells, in: gym.id)
        _ = try reopen().saveInventory([.init(2.5, .lb)], for: .plates, in: gym.id)
        for _ in 0..<2 {
            #expect(try suggestion(curl) == nil)
            let session = UUID()
            func perform(_ action: SessionCommand.Action) throws {
                _ = try reopen().apply(.init(sessionID: session, action: action), clock: SuggestionClock())
            }
            try perform(.start(routineID: routine.id, gymID: gym.id, dayID: day.id, cycleID: nil))
            try perform(
                .adjust(
                    exerciseID: curl.id, sets: 1, segments: [.repetitions(7)], load: .confirmed(dumbbellLoad(30)),
                    saveAsUsual: false))
            for exercise in exercises {
                try perform(
                    .completeSet(exerciseID: exercise.id, number: 1, performance: .init(asPrescribed: exercise)))
            }
            try perform(.finish)
            for exercise in exercises {
                try perform(.rateFinished(exerciseID: exercise.id, effort: .easy))
            }
        }
        let first = try #require(try suggestion(curl))
        #expect(first.load == dumbbellLoad(55) && first.repetitions == 15)
        _ = try reopen().saveInventory([.init(55, .lb)], for: .dumbbells, in: gym.id)
        let inclusive = try #require(try suggestion(row))
        #expect(inclusive.load == dumbbellLoad(55) && inclusive.repetitions == 10)
        _ = try reopen().saveInventory([.init(55.01, .lb)], for: .dumbbells, in: gym.id)
        #expect(try suggestion(curl)?.load == dumbbellLoad(55.01))
        #expect(try suggestion(curl)?.repetitions == 10)
        #expect(try suggestion(empty)?.load == barLoad(50))
        #expect(try suggestion(empty)?.repetitions == 8)
        #expect(try suggestion(press)?.load == barLoad(150))
        let bridge = try #require(try suggestion(lightPress))
        #expect(bridge.load == barLoad(65) && bridge.repetitions == 12)
        #expect(try suggestion(maximum)?.repetitions == 12)
        #expect(try suggestion(maximum)?.returnRepetitionsOnAcceptance == nil)
        _ = try reopen().saveInventory([.init(7.5, .lb)], for: .plates, in: gym.id)
        #expect(try suggestion(empty)?.load == barLoad(60))
        #expect(try suggestion(lightPress) == nil)
    }

    @Test(arguments: [(10, false), (12, false), (10, true)])
    func acceptsAndCompletesRepetitionBridge(startingRepetitions: Int, customizes: Bool) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        func reopen() -> CoordinatedModelStore { CoordinatedModelStore(trainingDirectory: directory) }

        let gym = try #require(try reopen().createGym(name: "Gym").gyms.first)
        let dumbbell = try #require(gym.genericEquipment.first { $0.kind == .dumbbell })
        let weights = [35, 45, 60].map { InventoryWeight(Decimal($0), .lb) }
        _ = try reopen().saveInventory(weights, for: .dumbbells, in: gym.id)
        func load(_ amount: Decimal) -> ExerciseLoad {
            .init(amount: amount, unit: .lb, representation: .perImplement, implementCount: 1)
        }
        var exercise = ExercisePrescription(name: "Row", sets: 1, segments: [.repetitions(startingRepetitions)])
        exercise.equipmentID = dumbbell.id
        exercise.load = .confirmed(load(35))
        let day = RoutineDay(name: "Day", exercises: [exercise])
        var routine = ManualRoutine(gymID: gym.id)
        routine.plan = RoutinePlan(name: "Plan", days: [day])
        try reopen().saveRoutine(routine)

        func usual() throws -> ExercisePrescription {
            try #require(try reopen().routine(id: routine.id)?.plan.days.first?.exercises.first)
        }
        func rateEasy() throws {
            let session = UUID()
            func perform(_ action: SessionCommand.Action) throws {
                _ = try reopen().apply(.init(sessionID: session, action: action), clock: SuggestionClock())
            }
            try perform(.start(routineID: routine.id, gymID: gym.id, dayID: day.id, cycleID: nil))
            try perform(.completeSet(exerciseID: exercise.id, number: 1, performance: .init(asPrescribed: usual())))
            try perform(.finish)
            try perform(.rateFinished(exerciseID: exercise.id, effort: .easy))
        }
        func suggestion() throws -> WeightSuggestion? {
            try reopen().suggestedWeightIncrease(routineID: routine.id, exerciseID: exercise.id)
        }
        func accept(_ proposal: WeightSuggestion) throws {
            try reopen().acceptWeightIncrease(
                proposal, routineID: routine.id, exerciseID: exercise.id, clock: SuggestionClock())
        }

        try rateEasy()
        try rateEasy()
        let bridge = try #require(try suggestion())
        let step = startingRepetitions == 10 ? 12 : 15
        #expect(bridge.load == load(35) && bridge.repetitions == step)
        #expect(try suggestion() == bridge)
        #expect(try usual() == exercise)
        _ = try reopen().saveInventory([.init(35, .lb)], for: .dumbbells, in: gym.id)
        #expect(throws: WeightSuggestionError.suggestionChanged) { try accept(bridge) }
        _ = try reopen().saveInventory(weights, for: .dumbbells, in: gym.id)
        if customizes {
            func start() throws -> UUID {
                let id = UUID()
                _ = try reopen().apply(
                    .init(
                        sessionID: id,
                        action:
                            .start(routineID: routine.id, gymID: gym.id, dayID: day.id, cycleID: nil)),
                    clock: SuggestionClock())
                return id
            }
            for _ in 0..<2 {
                let id = try start()
                let offer = try #require(try reopen().progressionOffer(routineID: routine.id, exerciseID: exercise.id))
                #expect(offer.advice == .suggested(bridge))
                #expect(offer.loads.contains(bridge.load))
                _ = try reopen().apply(
                    .init(sessionID: id, action: .logCurrentSet(exerciseID: exercise.id, number: 1)),
                    clock: SuggestionClock())
                #expect(throws: WeightSuggestionError.suggestionChanged) {
                    try reopen().acceptProgressionSuggestion(
                        bridge, load: load(35), repetitions: 11,
                        routineID: routine.id, exerciseID: exercise.id, sessionID: id, clock: SuggestionClock())
                }
                #expect(try usual() == exercise)
            }
            let id = try start()
            try reopen().acceptProgressionSuggestion(
                bridge, load: load(35), repetitions: 11, routineID: routine.id, exerciseID: exercise.id,
                sessionID: id, clock: SuggestionClock())
            let changes = try reopen().prescriptionChanges()
            #expect(changes.count == 1)
            #expect(changes[0].previous.segments == [.repetitions(startingRepetitions)])
            #expect(changes[0].updated.segments == [.repetitions(11)])
            #expect(changes[0].updated.load == .confirmed(load(35)))
            #expect(try reopen().openWorkout()?.nextSet?.exercise.segments == [.repetitions(11)])
            _ = try reopen().apply(
                .init(sessionID: id, action: .logCurrentSet(exerciseID: exercise.id, number: 1)),
                clock: SuggestionClock())
            #expect(try usual().segments == [.repetitions(11)])
            #expect(try suggestion() == nil)
            try rateEasy()
            #expect(try suggestion() == nil)
            try rateEasy()
            let recalculated = try #require(try suggestion())
            #expect(recalculated.load == load(35) && recalculated.repetitions == 12)
            try accept(recalculated)
        } else {
            try accept(bridge)
        }
        #expect(try usual().segments == [.repetitions(step)])
        #expect(try suggestion() == nil)
        #expect(throws: WeightSuggestionError.suggestionChanged) { try accept(bridge) }

        try rateEasy()
        #expect(try suggestion() == nil)
        try rateEasy()
        let heavier = try #require(try suggestion())
        #expect(heavier.load == load(45) && heavier.repetitions == startingRepetitions)
        try accept(heavier)
        let updated = try usual()
        #expect(updated.load == .confirmed(load(45)) && updated.segments == [.repetitions(startingRepetitions)])
        try rateEasy()
        try rateEasy()
        let nextBridge = try #require(try suggestion())
        #expect(nextBridge.load == load(45) && nextBridge.repetitions == step)
        if customizes {
            try reopen().acceptProgressionSuggestion(
                nextBridge, load: load(35), repetitions: step,
                routineID: routine.id, exerciseID: exercise.id, clock: SuggestionClock())
            #expect(try suggestion() == nil)
            try rateEasy()
            try rateEasy()
            let afterLoadEdit = try #require(try suggestion())
            #expect(afterLoadEdit.load == load(35) && afterLoadEdit.repetitions == 15)
        }
    }
}

private struct SuggestionClock: WorkoutClock {
    let now = Date(timeIntervalSinceReferenceDate: 100)
}
