import Foundation
import Testing
import TrainingDomain

struct GymLoadOptionsTests {
    @Test(arguments: [1, 2])
    func dumbbellsKeepOriginalUnitsAndTheChosenPieceCount(count: Int) throws {
        var inventory = GymInventory()
        inventory[.dumbbells] = [.init(10, .lb), .init(10, .kg)]

        let loads = inventory.loadOptions(for: .dumbbell, dumbbellCount: count)

        #expect(loads.map(\.unit) == [.lb, .kg])
        #expect(
            loads.allSatisfy { $0.amount == 10 && $0.representation == .perImplement && $0.implementCount == count })
        #expect(
            try loads.map { try $0.displayed(as: .combined).amount } == Array(repeating: Decimal(10 * count), count: 2))
    }

    @Test func fixedBarsUseTheTotalWeightOfOnePieceFromTheGym() {
        var inventory = GymInventory()
        inventory[.dumbbells] = [.init(10, .lb)]
        inventory[.fixedBars] = [.init(10, .kg)]
        let otherGym = GymInventory()

        #expect(
            inventory.loadOptions(for: .fixedBar) == [
                ExerciseLoad(
                    amount: 10, unit: .kg, representation: .combined, implementCount: 1)
            ])
        #expect(otherGym.loadOptions(for: .fixedBar).isEmpty)
    }

    @Test func selectorizedMachineOffersThirtyLoadsInStepsOfFiveKilograms() {
        let inventory = GymInventory()
        let loads = inventory.loadOptions(for: .selectorizedMachine)

        #expect(loads.count == 30)
        #expect(loads.map(\.amount) == (1...30).map { Decimal($0 * 5) })
        #expect(loads.allSatisfy { $0.unit == .kg && $0.representation == .combined && $0.implementCount == 1 })
    }

    @Test func selectorizedMachineUsesConfiguredLoadsAndUnits() {
        var machine = EquipmentDescription(name: "Pulldown", kind: .selectorizedMachine, unit: .lb)
        machine.availableLoads = [10, 20]

        #expect(
            GymInventory().loadOptions(for: machine)
                == machine.availableLoads.map {
                    ExerciseLoad(amount: $0, unit: .lb, representation: .combined, implementCount: 1)
                })
    }

    @Test func tinyPlateSizesProduceABoundedSelection() throws {
        let size = try #require(Decimal(string: "0.00001"))
        var inventory = GymInventory()
        inventory[.plates] = [.init(size, .kg)]
        var machine = EquipmentDescription(name: "Press", kind: .plateLoadedMachine, unit: .kg)
        machine.maximumAddedWeightPerSide = size * 2000

        let amounts = inventory.loadOptions(for: machine).map(\.amount)

        #expect(amounts.count <= 1024)
        #expect(amounts.starts(with: [0, size, size * 2]))
    }

    @Test func mixesPlateUnitsBeforeApplyingTheEquipmentLimit() throws {
        var inventory = GymInventory()
        inventory[.plates] = [.init(5, .lb), .init(2.5, .kg)]
        var machine = EquipmentDescription(name: "Machine", kind: .plateLoadedMachine, unit: .kg)
        machine.maximumAddedWeightPerSide = 5

        let loads = inventory.loadOptions(for: machine)

        let expected = try ["0", "2.26796185", "2.5", "4.5359237", "4.76796185", "5"].map { value in
            try #require(Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")))
        }
        #expect(loads.map(\.amount) == expected)
        #expect(loads.allSatisfy { $0.unit == .kg && $0.representation == .perSide && $0.implementCount == 2 })
    }

    @Test func emptyPlateInventoryOffersOnlyTheUnloadedEquipment() {
        let machine = EquipmentDescription(name: "Machine", kind: .plateLoadedMachine, unit: .kg)
        let unloaded = ExerciseLoad(amount: 0, unit: .kg, representation: .perSide, implementCount: 2)

        #expect(GymInventory().loadOptions(for: machine) == [unloaded])
    }
}
