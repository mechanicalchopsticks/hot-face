import Foundation
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
            #expect(selected.gyms.first { $0.id == secondID }?.equipment == [fixedBar])

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
            #expect(try store.saveEquipment(barbell, in: gym.id).gyms.first?.equipment == inventory)
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
