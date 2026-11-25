import Foundation

public struct WeightSuggestion: Equatable, Sendable {
    public let load: ExerciseLoad
    public let repetitions: Int

    /// Saved only on acceptance. A nil value clears any completed bridge.
    public let returnRepetitionsOnAcceptance: Int?

    public static func increase(
        for usual: ExercisePrescription, balance: Int, equipment: EquipmentDescription, inventory: GymInventory,
        returnRepetitions: Int? = nil
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
        guard let next = candidates.min(by: { $0.kilograms < $1.kilograms }) else { return nil }
        if let returnRepetitions {
            return Self(load: next.load, repetitions: returnRepetitions, returnRepetitionsOnAcceptance: nil)
        }
        if kilograms == 0 || next.kilograms * 10 <= kilograms * 11 {
            return Self(load: next.load, repetitions: repetitions, returnRepetitionsOnAcceptance: nil)
        }
        guard let step = [8, 10, 12, 15].first(where: { $0 > repetitions }),
            options.contains(where: { (try? $0.addedKilograms(equipment: equipment)) == kilograms })
        else { return nil }
        return Self(load: current, repetitions: step, returnRepetitionsOnAcceptance: repetitions)
    }
}
