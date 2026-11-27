import Foundation
import SwiftData
import Testing
import TrainingDomain
import TrainingRepositories

struct GymProfileTests {
    @Test func reassignmentKeepsExactLoadsAndChoosesTheClosestAvailableWeight() throws {
        try withTemporaryDirectory { directory in
            func reopen() -> CoordinatedModelStore { CoordinatedModelStore(trainingDirectory: directory) }
            let gym = try #require(try reopen().createGym(name: "Gym").gyms.first)
            let generic = try #require(gym.genericEquipment.first { $0.kind == .dumbbell })
            let specific = EquipmentDescription(name: "Dumbbells", kind: .dumbbell, unit: .kg)
            var source = EquipmentDescription(name: "Original band", kind: .band, unit: .kg)
            source.availableLoads = [32, 32.5, 34]
            var replacement = EquipmentDescription(name: "Replacement band", kind: .band, unit: .kg)
            replacement.availableLoads = [30, 35]
            var pounds = EquipmentDescription(name: "Pound band", kind: .band, unit: .lb)
            pounds.availableLoads = [70, 75]
            for item in [specific, source, replacement, pounds] {
                _ = try reopen().saveEquipment(item, in: gym.id)
            }
            let profile = try #require(try reopen().gymCatalog().gyms.first)

            func bandLoad(_ amount: Decimal) -> ExerciseLoad {
                ExerciseLoad(amount: amount, unit: .kg, representation: .combined, implementCount: 1)
            }
            var curl = ExercisePrescription(name: "Curl", segments: [.repetitions(8)])
            curl.equipmentID = generic.id
            let exact = ExerciseLoad(amount: 10, unit: .kg, representation: .perImplement, implementCount: 2)
            curl.load = .estimated(exact)
            profile.assignEquipment(specific.id, to: &curl)
            #expect(curl.load == .estimated(exact))

            var presses = [32, 32.5, 34].map { (amount: Decimal) in
                var press = ExercisePrescription(name: "Press", segments: [.repetitions(8)])
                press.equipmentID = source.id
                press.load = .confirmed(bandLoad(amount))
                profile.assignEquipment(replacement.id, to: &press)
                return press
            }
            #expect(
                presses.map(\.load) == [.confirmed(bandLoad(30)), .confirmed(bandLoad(30)), .confirmed(bandLoad(35))])
            var press = ExercisePrescription(name: "Mixed units", segments: [.repetitions(8)])
            press.equipmentID = source.id
            press.load = .confirmed(bandLoad(32))
            profile.assignEquipment(pounds.id, to: &press)
            #expect(press.load.value?.amount == 70 && press.load.value?.unit == .lb)
            press.load = .undefined
            profile.assignEquipment(source.id, to: &press)
            #expect(press.load == .undefined)
            presses.append(press)

            var draft = ManualRoutine(gymID: gym.id)
            draft.plan = RoutinePlan(name: "Strength", days: [RoutineDay(name: "Day 1", exercises: [curl] + presses)])
            try reopen().saveRoutine(draft)
            let saved = try #require(try reopen().activeRoutine())
            #expect(saved.plan.days[0].exercises == [curl] + presses)
        }
    }

    @Test func usesGenericEquipmentImmediatelyAndCanAssignSpecificEquipmentLater() throws {
        struct Clock: WorkoutClock {
            let now = Date(timeIntervalSince1970: 1000)
        }

        try withTemporaryDirectory { directory in
            func reopen() -> CoordinatedModelStore { CoordinatedModelStore(trainingDirectory: directory) }
            let gym = try #require(try reopen().createGym(name: "Gym").gyms.first)
            #expect(gym.equipment.isEmpty)
            #expect(gym.genericEquipment.map(\.kind) == EquipmentDescription.Kind.allCases)
            #expect(Set(gym.genericEquipment.map(\.id)).count == 8)
            let second = try #require(try reopen().createGym(name: "Other gym").gyms.first { $0.id != gym.id })
            #expect(Set(gym.genericEquipment.map(\.id)).isDisjoint(with: second.genericEquipment.map(\.id)))
            let bar = try #require(gym.genericEquipment.first { $0.kind == .barbell })
            #expect(bar.baseWeight == 45 && bar.unit == .lb)
            let load = try #require(gym.loadOptions(for: bar.id).first { $0.amount == 15 && $0.unit == .lb })

            var press = ExercisePrescription(name: "Press", segments: [.repetitions(8)])
            press.equipmentID = bar.id
            press.load = .confirmed(load)
            var row = ExercisePrescription(name: "Row", segments: [.repetitions(8)])
            row.equipmentID = bar.id
            let day = RoutineDay(name: "A", exercises: [press, row])
            var draft = ManualRoutine(gymID: gym.id)
            draft.plan = RoutinePlan(name: "Strength", days: [day])
            try reopen().saveRoutine(draft)

            var specific = EquipmentDescription(name: "Olympic bar", kind: .barbell, unit: .lb)
            specific.station = "3"
            _ = try reopen().saveEquipment(specific, in: gym.id)
            draft = try #require(try reopen().activeRoutine())
            draft.plan.days[0].exercises[1].equipmentID = specific.id
            try reopen().saveRoutine(draft)

            let catalog = try reopen().gymCatalog()
            let updated = try #require(catalog.gyms.first { $0.id == gym.id })
            #expect(updated.genericEquipment == gym.genericEquipment && updated.equipment == [specific])
            let saved = try #require(try reopen().activeRoutine())
            #expect(saved.plan.days[0].exercises.map(\.equipmentID) == [bar.id, specific.id])
            #expect(saved.plan.days[0].exercises.first?.load == .confirmed(load))
            let sessionID = UUID()
            _ = try reopen().apply(
                SessionCommand(
                    sessionID: sessionID,
                    action: .start(routineID: saved.id, gymID: gym.id, dayID: day.id, cycleID: nil)),
                clock: Clock())
            try reopen().withContext { context in
                let session = try #require(context.fetch(FetchDescriptor<TrainingSchemaV1.Session>()).first)
                #expect(session.id == sessionID)
                #expect(try session.prescription.equipment == [specific, bar])
            }
        }
    }

    @Test func editsAndSelectsGymsWithoutMixingEquipment() throws {
        try withTemporaryDirectory { directory in
            func reopen() -> CoordinatedModelStore { CoordinatedModelStore(trainingDirectory: directory) }

            let empty = try reopen().gymCatalog()
            #expect(empty.gyms.isEmpty && empty.activeGymID == nil)
            let first = try reopen().createGym(name: "Gimnasio A")
            let firstID = try #require(first.gyms.first?.id)
            #expect(first.activeGymID == firstID)
            let second = try reopen().createGym(name: "Gimnasio B")
            let secondID = try #require(second.gyms.first { $0.name == "Gimnasio B" }?.id)
            #expect(second.activeGymID == firstID)

            var barbell = EquipmentDescription(name: "Barra", kind: .barbell, unit: .kg)
            barbell.station = "Estación 4"
            barbell.baseWeight = 20
            barbell.availableLoads = [0, 12.5]
            barbell.plates = [PlateInventory(weight: 2.5, count: 4)]
            var fixedBar = EquipmentDescription(name: "Barra", kind: .fixedBar, unit: .lb)
            fixedBar.availableLoads = [30, 35]
            _ = try reopen().saveEquipment(barbell, in: firstID)
            _ = try reopen().saveEquipment(fixedBar, in: secondID)

            let selected = try reopen().selectGym(secondID)
            #expect(selected.activeGymID == secondID)
            let secondProfile = try #require(selected.gyms.first { $0.id == secondID })
            #expect(secondProfile.inventory.fixedBars.suffix(2) == [.init(30, .lb), .init(35, .lb)])
            fixedBar.availableLoads = []
            #expect(secondProfile.equipment == [fixedBar])

            barbell.name = "Barra olímpica"
            barbell.availableLoads.append(17.5)
            barbell.plates[0].count = 6
            _ = try reopen().saveEquipment(barbell, in: firstID)
            _ = try reopen().renameGym(firstID, name: "Gimnasio Ñ")
            let reselected = try reopen().selectGym(firstID)
            #expect(reselected.activeGymID == firstID)

            let saved = try reopen().gymCatalog()
            #expect(saved.activeGymID == firstID)
            #expect(saved.gyms.first { $0.id == firstID }?.name == "Gimnasio Ñ")
            barbell.plates = []
            #expect(saved.gyms.first { $0.id == firstID }?.inventory.plates.last == .init(2.5, .kg))
            #expect(saved.gyms.first { $0.id == firstID }?.equipment == [barbell])
            #expect(saved.gyms.first { $0.id == secondID }?.equipment == [fixedBar])
        }
    }

    @Test func rejectsInvalidLoadsAndUnknownGymWithoutChangingTheCatalog() throws {
        try withTemporaryDirectory { directory in
            let store = CoordinatedModelStore(trainingDirectory: directory)
            let catalog = try store.createGym(name: "Gym")
            let gymID = try #require(catalog.activeGymID)
            var equipment = EquipmentDescription(name: "Dumbbells", kind: .dumbbell, unit: .lb)
            equipment.availableLoads = [-5]

            #expect(throws: GymProfileError.invalidLoads) { try store.saveEquipment(equipment, in: gymID) }
            #expect(throws: GymProfileError.missingGym) { try store.selectGym(UUID()) }
            #expect(throws: GymProfileError.emptyName) { try store.renameGym(gymID, name: "  ") }
            let saved = try store.gymCatalog()
            #expect(saved.activeGymID == gymID)
            #expect(saved.gyms.count == 1)
            #expect(saved.gyms.first?.name == "Gym")
            #expect(saved.gyms.first?.equipment.isEmpty == true)
        }
    }

    @Test func opensFrozenV2CatalogAndDecodesEquipmentWrittenBeforeStationsExisted() throws {
        try withTemporaryDirectory { directory in
            let oldStore = try fixture("closed-session-v2", extension: "store")
            try FileManager.default.copyItem(at: oldStore, to: directory.appendingPathComponent("training.store"))
            let store = CoordinatedModelStore(trainingDirectory: directory)
            let catalog = try store.gymCatalog()
            let gym = try #require(catalog.gyms.first)
            #expect(gym.name == "Fixture gym")
            #expect(catalog.activeGymID == nil)

            let oldEquipment = try Data(contentsOf: fixture("equipment-v2", extension: "json"))
            let inventory = try JSONDecoder().decode([EquipmentDescription].self, from: oldEquipment)
            let barbell = try #require(inventory.first)
            #expect(barbell.name == "Barra olímpica" && barbell.station == nil)
            #expect(barbell.kind == .barbell && barbell.unit == .kg)
            #expect(barbell.availableLoads == [0, 12.5] && barbell.baseWeight == 20)
            #expect(barbell.plates == [PlateInventory(weight: 2.5, count: 4)])
            #expect(try store.selectGym(gym.id).activeGymID == gym.id)
            let updated = try #require(store.saveEquipment(barbell, in: gym.id).gyms.first)
            var migrated = barbell
            migrated.plates = []
            #expect(updated.equipment == [migrated])
            #expect(updated.inventory.plates.contains(.init(2.5, .kg)))
        }
    }

    @Test func migratesFrozenV3InventoriesWithoutRewritingHistory() throws {
        try withTemporaryDirectory { directory in
            try FileManager.default.copyItem(
                at: fixture("shared-equipment-v3", extension: "store"),
                to: directory.appendingPathComponent("training.store"))
            func reopen() -> CoordinatedModelStore { CoordinatedModelStore(trainingDirectory: directory) }
            let catalog = try reopen().gymCatalog()
            let gym = try #require(catalog.gyms.first)
            #expect(catalog.activeGymID == gym.id)
            #expect(gym.genericEquipment.map(\.kind) == EquipmentDescription.Kind.allCases)
            #expect(Set(gym.genericEquipment.map(\.id)).isDisjoint(with: gym.equipment.map(\.id)))
            #expect(gym.inventory.plates == [.init(5, .lb), .init(10, .lb)])
            #expect(gym.inventory.dumbbells == [.init(10, .lb), .init(10, .kg)])
            #expect(gym.inventory.fixedBars == [.init(10, .kg)])
            let bar = try #require(gym.equipment.first { $0.kind == .barbell })
            let saved = try #require(try reopen().activeRoutine())
            #expect(saved.plan.days.first?.exercises.first?.equipmentID == bar.id)
            #expect(bar.baseWeight == 35 && bar.availableLoads == [30] && bar.plates.isEmpty)
            #expect(gym.equipment.first { $0.kind == .plateLoadedMachine }?.baseWeight == 12.5)
            _ = try reopen().saveInventory([], for: .plates, in: gym.id)
            let reopened = try #require(reopen().gymCatalog().gyms.first)
            #expect(reopened.inventory.plates == [])
            #expect(reopened.genericEquipment == gym.genericEquipment)
            try reopen().withContext { context in
                let session = try #require(context.fetch(FetchDescriptor<TrainingSchemaV1.Session>()).first)
                let snapshot = try session.prescription
                #expect(session.finishedAt != nil && snapshot.gymID == gym.id)
                #expect(snapshot.day.exercises.first?.equipmentID == bar.id)
                let original = try #require(snapshot.equipment.first)
                #expect(original.id == bar.id && original.baseWeight == 35)
                #expect(original.plates == [.init(weight: 5, count: 4), .init(weight: 10, count: 2)])
            }
        }
    }

    @Test func newGymsSeedIndependentInventoriesOnce() throws {
        try withTemporaryDirectory { directory in
            let store = CoordinatedModelStore(trainingDirectory: directory)
            let first = try #require(store.createGym(name: "A").gyms.first)
            #expect(first.inventory.plates == [2.5, 5, 10, 25, 35, 45].map { InventoryWeight($0, .lb) })
            #expect(
                first.inventory.dumbbells == [2.5, 5, 10, 15, 20, 25, 30, 35, 40, 50, 60, 70, 80, 90, 100].map {
                    InventoryWeight($0, .lb)
                } + [5, 7.5, 10, 12.5].map { InventoryWeight($0, .kg) })
            #expect(first.inventory.fixedBars == [10, 15, 20, 25, 30, 35, 40, 50].map { InventoryWeight($0, .kg) })
            _ = try store.createGym(name: "B")
            _ = try store.saveInventory([.init(22.5, .lb), .init(10, .kg)], for: .dumbbells, in: first.id)
            let catalog = try CoordinatedModelStore(trainingDirectory: directory).gymCatalog()
            #expect(
                catalog.gyms.first { $0.id == first.id }?.inventory.dumbbells == [.init(22.5, .lb), .init(10, .kg)])
            #expect(catalog.gyms.first { $0.id != first.id }?.inventory == first.inventory)
        }
    }

    @Test(arguments: [EquipmentDescription.Kind.barbell, .plateLoadedMachine])
    func savesAndClearsOptionalMaximumIndependentlyOfBaseWeight(kind: EquipmentDescription.Kind) throws {
        try withTemporaryDirectory { directory in
            func reopen() -> CoordinatedModelStore { CoordinatedModelStore(trainingDirectory: directory) }
            let gymID = try #require(try reopen().createGym(name: "Gym").activeGymID)
            var item = EquipmentDescription(name: "Station", kind: kind, unit: .lb)
            item.baseWeight = 45
            item.maximumAddedWeightPerSide = 90
            _ = try reopen().saveEquipment(item, in: gymID)
            #expect(try reopen().gymCatalog().gyms.first?.equipment == [item])
            item.maximumAddedWeightPerSide = -1
            #expect(throws: GymProfileError.invalidLoads) { try reopen().saveEquipment(item, in: gymID) }
            item.maximumAddedWeightPerSide = nil
            _ = try reopen().saveEquipment(item, in: gymID)
            #expect(try reopen().gymCatalog().gyms.first?.equipment == [item])
        }
    }

    @Test func plateEquipmentReadsTheEditedGymInventoryAndItsOwnPerSideLimit() throws {
        try withTemporaryDirectory { directory in
            func reopen() -> CoordinatedModelStore { CoordinatedModelStore(trainingDirectory: directory) }

            let gymID = try #require(try reopen().createGym(name: "Gym").activeGymID)
            var barbell = EquipmentDescription(name: "Barbell", kind: .barbell, unit: .lb)
            barbell.baseWeight = 45
            var machine = EquipmentDescription(name: "Machine", kind: .plateLoadedMachine, unit: .lb)
            machine.baseWeight = 60
            machine.maximumAddedWeightPerSide = 90
            _ = try reopen().saveEquipment(barbell, in: gymID)
            _ = try reopen().saveEquipment(machine, in: gymID)

            let gym = try #require(reopen().gymCatalog().gyms.first)
            let barLoads = gym.loadOptions(for: barbell.id)
            let machineLoads = gym.loadOptions(for: machine.id)
            for loads in [barLoads, machineLoads] {
                let totals = try loads.map { try $0.displayed(as: .totalAdded).amount }
                #expect(totals.contains(30))
                #expect(!totals.contains(31))
            }
            #expect(try barLoads.last?.displayed(as: .totalAdded).amount == 500)
            #expect(try barLoads.last?.displayed(as: .includingEquipment, equipmentWeightInLoadUnit: 45).amount == 545)
            let barTotals = try barLoads.map { try $0.displayed(as: .totalAdded).amount }
            #expect(!barTotals.contains(505))
            #expect(try machineLoads.last?.displayed(as: .totalAdded).amount == 180)
            #expect(
                try machineLoads.last?.displayed(as: .includingEquipment, equipmentWeightInLoadUnit: 60).amount == 240)

            let remaining = gym.inventory.plates.filter { $0.amount >= 10 }
            _ = try reopen().saveInventory(remaining, for: .plates, in: gymID)
            let updated = try #require(reopen().gymCatalog().gyms.first)
            for item in [barbell, machine] {
                let totals = try updated.loadOptions(for: item.id).map { try $0.displayed(as: .totalAdded).amount }
                #expect(!totals.contains(30))
                #expect(totals.contains(40))
            }
        }
    }

    @Test func selectedLoadChangesRepresentationAndKeepsTheStoredBalance() throws {
        try withTemporaryDirectory { directory in
            func reopen() -> CoordinatedModelStore { CoordinatedModelStore(trainingDirectory: directory) }
            let gymID = try #require(try reopen().createGym(name: "Gym A").activeGymID)
            let dumbbells = EquipmentDescription(name: "Rack", kind: .dumbbell, unit: .lb)
            _ = try reopen().saveEquipment(dumbbells, in: gymID)
            _ = try reopen().saveInventory([.init(10, .lb), .init(10, .kg)], for: .dumbbells, in: gymID)
            let otherGym = try #require(try reopen().createGym(name: "Gym B").gyms.first { $0.id != gymID })
            #expect(otherGym.loadOptions(for: dumbbells.id).isEmpty)

            let gym = try #require(reopen().gymCatalog().gyms.first { $0.id == gymID })
            let options = gym.loadOptions(for: dumbbells.id, dumbbellCount: 2)
            #expect(options.map(\.unit) == [.lb, .kg])
            let weight = try #require(options.first { $0.unit == .kg })
            var exercise = ExercisePrescription(name: "Curl", sets: 3, segments: [.repetitions(10)])
            exercise.equipmentID = dumbbells.id
            exercise.load = .confirmed(weight)
            let day = RoutineDay(name: "Day", exercises: [exercise])
            try reopen().withContext { context in
                let routine = try TrainingSchemaV1.Routine(
                    gymID: gymID, plan: RoutinePlan(name: "Routine", days: [day]))
                let progression = TrainingSchemaV1.Progression(exerciseID: exercise.id)
                progression.balance = 2
                context.insert(routine)
                context.insert(progression)
                try context.save()
            }
            var draft = try #require(try reopen().activeRoutine())
            draft.plan.days[0].exercises[0].load = .confirmed(try weight.displayed(as: .combined))
            try reopen().saveRoutine(draft)
            try reopen().withContext { context in
                let routine = try #require(context.fetch(FetchDescriptor<TrainingSchemaV1.Routine>()).first)
                let expected = ExerciseLoad(amount: 20, unit: .kg, representation: .combined, implementCount: 2)
                #expect(try routine.plan.days[0].exercises[0].load == .confirmed(expected))
                let progression = try #require(context.fetch(FetchDescriptor<TrainingSchemaV1.Progression>()).first)
                #expect(progression.exerciseID == exercise.id && progression.balance == 2)
                #expect(try context.fetchCount(FetchDescriptor<TrainingSchemaV1.PrescriptionChange>()) == 0)
            }
        }
    }

    private func fixture(_ name: String, extension fileExtension: String) throws -> URL {
        try #require(Bundle.module.url(forResource: name, withExtension: fileExtension, subdirectory: "Fixtures"))
    }

    private func withTemporaryDirectory(_ test: (URL) throws -> Void) throws {
        let files = FileManager.default
        let directory = files.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try files.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? files.removeItem(at: directory) }
        try test(directory)
    }
}
