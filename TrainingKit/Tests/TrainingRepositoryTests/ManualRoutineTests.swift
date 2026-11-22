import Foundation
import Testing
import TrainingDomain
import TrainingRepositories

struct ManualRoutineTests {
    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @Test func editsAManualRoutineWithIndependentLoadsFromSharedPlates() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        func reopen() -> CoordinatedModelStore { CoordinatedModelStore(trainingDirectory: directory) }

        let gymID = try #require(reopen().createGym(name: "Gym A").activeGymID)
        let secondGym = try #require(reopen().createGym(name: "Gym B").gyms.first { $0.id != gymID })
        let bar = EquipmentDescription(name: "Bar", kind: .barbell, unit: .lb)
        let machine = EquipmentDescription(name: "Press", kind: .plateLoadedMachine, unit: .lb)
        _ = try reopen().saveEquipment(bar, in: gymID)
        _ = try reopen().saveEquipment(machine, in: gymID)
        let catalog = try reopen().saveInventory([InventoryWeight(7, .lb)], for: .plates, in: gymID)
        let gym = try #require(catalog.gyms.first { $0.id == gymID })
        let barOptions = gym.loadOptions(for: bar.id)
        let machineOptions = gym.loadOptions(for: machine.id)
        #expect(barOptions == machineOptions)
        let light = try #require(barOptions.first { $0.amount == 7 })
        let heavy = try #require(machineOptions.first { $0.amount == 14 })

        let hold = ExercisePrescription(name: "Plank", sets: 2, segments: [.seconds(30)])
        var unilateral = ExercisePrescription(name: "Press", sets: 3, segments: [.repetitions(8)])
        unilateral.equipmentID = machine.id
        unilateral.perSide = true
        unilateral.load = .confirmed(heavy)
        var curls = ExercisePrescription(name: "Curls", sets: 4, segments: Array(repeating: .repetitions(7), count: 3))
        curls.equipmentID = bar.id
        curls.variant = "Partial, partial, full"
        curls.load = .confirmed(light)
        curls.restBetweenSets = 75
        curls.restAfterExercise = 0

        var draft = ManualRoutine(gymID: gymID)
        draft.plan = RoutinePlan(
            name: "Strength",
            days: [
                RoutineDay(name: "A", exercises: [hold, unilateral, curls]),
                RoutineDay(
                    name: "B", exercises: [ExercisePrescription(name: "Walk", sets: 1, segments: [.seconds(60)])]),
            ], restBetweenSets: 90, restBetweenExercises: 150)
        try reopen().saveRoutine(draft)
        var saved = try #require(reopen().editableRoutines(in: gymID).first)
        #expect(saved.plan == draft.plan)
        #expect(try reopen().editableRoutines(in: secondGym.id).isEmpty)

        let stale = saved
        let zero = try #require(machineOptions.first { $0.amount == 0 })
        saved.plan.days[0].exercises[1].load = .confirmed(zero)
        saved.plan.days.swapAt(0, 1)
        try reopen().saveRoutine(saved)
        #expect(throws: RoutineEditorError.changedRoutine) { try reopen().saveRoutine(stale) }
        let edited = try #require(reopen().editableRoutines(in: gymID).first)
        #expect(edited.plan == saved.plan)
        #expect(edited.plan.days[1].exercises.map(\.load) == [.undefined, .confirmed(zero), .confirmed(light)])
        #expect(edited.revision == saved.revision + 1)

        var incomplete = edited
        incomplete.plan.days[1].exercises[0].segments = []
        #expect(throws: RoutineEditorError.incompletePlan) { try reopen().saveRoutine(incomplete) }
        #expect(try reopen().editableRoutines(in: gymID).first?.plan == edited.plan)
    }

    @Test func inheritsAcrossDaysAndRestoresInheritanceAfterReopening() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        func reopen() -> CoordinatedModelStore { CoordinatedModelStore(trainingDirectory: directory) }
        let gymID = try #require(reopen().createGym(name: "Gym").activeGymID)
        func read() throws -> ManualRoutine { try #require(reopen().editableRoutines(in: gymID).first) }
        func counts(_ plan: RoutinePlan) -> [[Int]] {
            plan.days.map { $0.exercises.map(plan.setCount(for:)) }
        }
        var draft = ManualRoutine(gymID: gymID)
        #expect(draft.plan.defaultSets == 4)
        draft.plan.name = "Plan"
        draft.plan.days = [
            RoutineDay(
                name: "A",
                exercises: [
                    ExercisePrescription(name: "Curl", segments: [.repetitions(8)]),
                    ExercisePrescription(name: "Row", sets: 3, segments: [.repetitions(8)]),
                ]),
            RoutineDay(
                name: "B",
                exercises: [
                    ExercisePrescription(name: "Plank", segments: [.seconds(30)]),
                    ExercisePrescription(name: "Squat", sets: 5, segments: [.repetitions(8)]),
                ]),
        ]
        #expect(counts(draft.plan) == [[4, 3], [4, 5]])
        draft.plan.defaultSets = 3
        try reopen().saveRoutine(draft)
        var edited = try read()
        #expect(counts(edited.plan) == [[3, 3], [3, 5]])
        edited.plan.defaultSets = 4
        #expect(counts(edited.plan) == [[4, 3], [4, 5]])
        try reopen().saveRoutine(edited)
        edited = try read()
        #expect(counts(edited.plan) == [[4, 3], [4, 5]])
        edited.plan.days[1].exercises[1].sets = nil
        #expect(counts(edited.plan) == [[4, 3], [4, 4]])
        try reopen().saveRoutine(edited)
        edited = try read()
        edited.plan.defaultSets = 2
        #expect(counts(edited.plan) == [[2, 3], [2, 2]])

        edited.plan.defaultSets = 0
        #expect(throws: RoutineEditorError.incompletePlan) { try reopen().saveRoutine(edited) }
        edited.plan.defaultSets = 2
        edited.plan.days[0].exercises[1].sets = -1
        #expect(throws: RoutineEditorError.incompletePlan) { try reopen().saveRoutine(edited) }
        #expect(try counts(read().plan) == [[4, 3], [4, 4]])
    }

    @Test func preservesExplicitSingleSetFromFrozenRoutine() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fixture = try #require(
            Bundle.module.url(forResource: "shared-equipment-v3", withExtension: "store", subdirectory: "Fixtures"))
        try FileManager.default.copyItem(at: fixture, to: directory.appendingPathComponent("training.store"))
        func reopen() -> CoordinatedModelStore { CoordinatedModelStore(trainingDirectory: directory) }
        let gymID = try #require(reopen().gymCatalog().activeGymID)
        var routine = try #require(reopen().editableRoutines(in: gymID).first)
        #expect(routine.plan.defaultSets == 1)
        #expect(routine.plan.days[0].exercises[0].sets == 1)
        routine.plan.defaultSets = 4
        try reopen().saveRoutine(routine)
        routine = try #require(reopen().editableRoutines(in: gymID).first)
        #expect(routine.plan.setCount(for: routine.plan.days[0].exercises[0]) == 1)
        routine.plan.days[0].exercises[0].sets = nil
        try reopen().saveRoutine(routine)
        routine = try #require(reopen().editableRoutines(in: gymID).first)
        #expect(routine.plan.setCount(for: routine.plan.days[0].exercises[0]) == 4)
    }
}
