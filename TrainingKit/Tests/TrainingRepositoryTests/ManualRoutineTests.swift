import Foundation
import Testing
import TrainingDomain
import TrainingRepositories

struct ManualRoutineTests {
    @Test func editsAManualRoutineWithIndependentLoadsFromSharedPlates() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
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
}
