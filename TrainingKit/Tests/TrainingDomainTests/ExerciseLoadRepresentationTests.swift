import Foundation
import Testing
import TrainingDomain

struct ExerciseLoadRepresentationTests {
    @Test(arguments: [1, 2])
    func dumbbellDisplayPreservesWeightAndNumberOfPieces(count: Int) throws {
        let load = ExerciseLoad(amount: 10, unit: .kg, representation: .perImplement, implementCount: count)
        let total = try load.displayed(as: .combined)

        #expect(total.amount == Decimal(10 * count))
        #expect(total.unit == .kg)
        #expect(total.implementCount == count)
        #expect(try total.displayed(as: .perImplement) == load)
    }

    @Test func plateDisplayRoundTripsWithAndWithoutEquipmentWeight() throws {
        let load = ExerciseLoad(amount: 12.5, unit: .lb, representation: .perSide, implementCount: 2)
        let added = try load.displayed(as: .totalAdded)
        let full = try load.displayed(as: .includingEquipment, equipmentWeightInLoadUnit: 45)

        #expect(added.amount == 25)
        #expect(full.amount == 70)
        #expect(try added.displayed(as: .perSide) == load)
        #expect(try added.displayed(as: .includingEquipment, equipmentWeightInLoadUnit: 45) == full)
        #expect(try full.displayed(as: .totalAdded, equipmentWeightInLoadUnit: 45) == added)
        #expect(try full.displayed(as: .perSide, equipmentWeightInLoadUnit: 45) == load)
    }

    @Test func includingEquipmentRequiresKnownWeight() throws {
        let load = ExerciseLoad(amount: 0, unit: .kg, representation: .perSide, implementCount: 2)

        #expect(throws: ExerciseLoad.ConversionError.missingEquipmentWeight) {
            try load.displayed(as: .includingEquipment)
        }
        #expect(try load.displayed(as: .includingEquipment, equipmentWeightInLoadUnit: 0).amount == 0)
        #expect(throws: ExerciseLoad.ConversionError.incompatibleRepresentation) {
            try load.displayed(as: .perImplement)
        }
    }

    @Test(arguments: [ExerciseLoad.Representation.perSide, .totalAdded, .includingEquipment])
    func platePercentageUsesOnlyAddedWeightInEveryView(representation: ExerciseLoad.Representation) throws {
        let current = ExerciseLoad(amount: 10, unit: .kg, representation: .perSide, implementCount: 2)
        let target = ExerciseLoad(amount: 12.5, unit: .kg, representation: .perSide, implementCount: 2)
        let baseWeight = InventoryWeight(20, .kg)
        let displayedCurrent = try current.displayed(as: representation, equipmentWeightInLoadUnit: baseWeight.amount)
        let displayedTarget = try target.displayed(as: representation, equipmentWeightInLoadUnit: baseWeight.amount)

        #expect(
            try displayedCurrent.addedWeightPercentageChange(to: displayedTarget, equipmentWeight: baseWeight) == 25)
        #expect(try displayedCurrent.addedWeightPercentageChange(to: target, equipmentWeight: baseWeight) == 25)
    }

    @Test func unloadedEquipmentHasNoPercentageChange() throws {
        let baseWeight = InventoryWeight(45, .lb)
        let unloaded = ExerciseLoad(amount: 45, unit: .lb, representation: .includingEquipment, implementCount: 2)
        let target = ExerciseLoad(amount: 2.5, unit: .lb, representation: .perSide, implementCount: 2)

        #expect(try unloaded.addedWeightPercentageChange(to: target, equipmentWeight: baseWeight) == nil)
    }
}
