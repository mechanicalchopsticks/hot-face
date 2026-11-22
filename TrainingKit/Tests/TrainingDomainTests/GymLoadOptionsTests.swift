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
}
