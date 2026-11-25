import Foundation

extension GymInventory {
    typealias WeightedLoad = (load: ExerciseLoad, kilograms: Decimal)

    public func loadOptions(for kind: EquipmentDescription.Kind, dumbbellCount: Int = 1) -> [ExerciseLoad] {
        inventoryOptions(for: kind, equipment: nil, dumbbellCount: dumbbellCount).map(\.load)
    }

    public func loadOptions(for equipment: EquipmentDescription, dumbbellCount: Int = 1) -> [ExerciseLoad] {
        inventoryOptions(for: equipment.kind, equipment: equipment, dumbbellCount: dumbbellCount).map(\.load)
    }

    public func loadOptions(for equipment: EquipmentDescription, displayedLike current: ExerciseLoad) -> [ExerciseLoad]
    {
        weightedOptions(for: equipment, displayedLike: current).map(\.load)
    }

    func weightedOptions(for equipment: EquipmentDescription, displayedLike current: ExerciseLoad) -> [WeightedLoad] {
        inventoryOptions(for: equipment.kind, equipment: equipment, dumbbellCount: current.implementCount).compactMap {
            option in
            let base = equipment.baseWeight.map { equipment.unit.converted($0, to: option.load.unit) }
            guard let load = try? option.load.displayed(as: current.representation, equipmentWeightInLoadUnit: base)
            else { return nil }
            return (load, option.kilograms)
        }
    }

    private func inventoryOptions(
        for kind: EquipmentDescription.Kind, equipment: EquipmentDescription?, dumbbellCount: Int
    ) -> [WeightedLoad] {
        let weights: [InventoryWeight]
        switch kind {
        case .barbell, .plateLoadedMachine:
            return plateLoadOptions(unit: equipment?.unit ?? .lb, maximumPerSide: equipment?.maximumAddedWeightPerSide)
        case .dumbbell:
            guard (1...2).contains(dumbbellCount) else { return [] }
            weights = dumbbells
        case .fixedBar:
            weights = fixedBars
        case .selectorizedMachine where equipment?.availableLoads.isEmpty ?? true:
            weights = stride(from: 5, through: 150, by: 5).map { InventoryWeight(Decimal($0), .kg) }
        case .selectorizedMachine, .bodyweight, .band, .cardio:
            guard let equipment else { return [] }
            weights = equipment.availableLoads.map { InventoryWeight($0, equipment.unit) }
        }
        let count = kind == .dumbbell ? dumbbellCount : 1
        return weights.map { weight in
            let load = ExerciseLoad(
                amount: weight.amount, unit: weight.unit,
                representation: kind == .dumbbell ? .perImplement : .combined, implementCount: count)
            return (load, weight.unit.converted(weight.amount * Decimal(count), to: .kg))
        }
    }

    private func plateLoadOptions(unit: ExerciseLoad.Unit, maximumPerSide: Decimal?) -> [WeightedLoad] {
        let globalMaximum = ExerciseLoad.Unit.lb.converted(250, to: .kg)
        let equipmentMaximum = maximumPerSide.map { unit.converted($0, to: .kg) } ?? globalMaximum
        guard !equipmentMaximum.isNaN, equipmentMaximum >= 0 else { return [] }
        let limit = min(globalMaximum, equipmentMaximum)

        // Kilograms keep the conversion from pounds exact while summing mixed sizes.
        let sizes = Set(
            plates.map { $0.unit.converted($0.amount, to: .kg) }
                .filter { !$0.isNaN && $0 > 0 && $0 <= limit }
        ).sorted()
        var reachable: Set<Decimal> = [0]
        // Bound the picker even for saved fractional sizes. Visit combinations with fewer plates first.
        let maximumOptions = 1024
        var pending: [Decimal] = [0]
        var index = 0
        search: while index < pending.count {
            let weight = pending[index]
            index += 1
            for size in sizes {
                let next = weight + size
                if next > limit { break }
                if reachable.insert(next).inserted {
                    pending.append(next)
                    if reachable.count == maximumOptions { break search }
                }
            }
        }
        return reachable.sorted().map { perSide in
            let load = ExerciseLoad(
                amount: ExerciseLoad.Unit.kg.converted(perSide, to: unit), unit: unit, representation: .perSide,
                implementCount: 2)
            return (load, perSide * 2)
        }
    }
}
