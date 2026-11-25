import Foundation

public struct WeightSuggestion: Equatable, Sendable {
    public let load: ExerciseLoad
    public let repetitions: Int

    /// A direct increase uses the lightest reachable heavier load and keeps the usual repetitions.
    public static func increase(
        for usual: ExercisePrescription, balance: Int, equipment: EquipmentDescription, inventory: GymInventory
    ) -> Self? {
        guard balance == 2, usual.equipmentID == equipment.id, usual.segments.count == 1,
            case .repetitions(let repetitions) = usual.segments[0], let current = usual.load.value,
            let kilograms = try? current.addedKilograms(equipment: equipment)
        else { return nil }

        let options = inventory.loadOptions(for: equipment, dumbbellCount: current.implementCount)
        let candidates = options.compactMap { option -> (load: ExerciseLoad, kilograms: Decimal)? in
            guard let weight = try? option.addedKilograms(equipment: equipment), weight > kilograms else { return nil }
            let base = equipment.baseWeight.map { equipment.unit.converted($0, to: option.unit) }
            guard let displayed = try? option.displayed(as: current.representation, equipmentWeightInLoadUnit: base)
            else { return nil }
            return (displayed, weight)
        }
        guard let next = candidates.min(by: { $0.kilograms < $1.kilograms }),
            kilograms == 0 || next.kilograms * 10 <= kilograms * 11
        else { return nil }
        return Self(load: next.load, repetitions: repetitions)
    }
}
