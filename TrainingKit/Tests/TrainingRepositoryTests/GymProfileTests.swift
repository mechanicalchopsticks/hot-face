import Foundation
import SwiftData
import Testing
import TrainingDomain
import TrainingRepositories

struct GymProfileTests {
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
            #expect(gym.inventory.plates == [.init(5, .lb), .init(10, .lb)])
            #expect(gym.inventory.dumbbells == [.init(10, .lb), .init(10, .kg)])
            #expect(gym.inventory.fixedBars == [.init(10, .kg)])
            let bar = try #require(gym.equipment.first { $0.kind == .barbell })
            #expect(bar.baseWeight == 35 && bar.availableLoads == [30] && bar.plates.isEmpty)
            #expect(gym.equipment.first { $0.kind == .plateLoadedMachine }?.baseWeight == 12.5)
            _ = try reopen().saveInventory([], for: .plates, in: gym.id)
            #expect(try reopen().gymCatalog().gyms.first?.inventory.plates == [])
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
            let gymID = try #require(reopen().createGym(name: "Gym").activeGymID)
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
