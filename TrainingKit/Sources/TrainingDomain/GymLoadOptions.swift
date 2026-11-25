import Foundation

extension GymInventory {
    public func loadOptions(for kind: EquipmentDescription.Kind, dumbbellCount: Int = 1) -> [ExerciseLoad] {
        switch kind {
        case .dumbbell:
            guard (1...2).contains(dumbbellCount) else { return [] }
            return dumbbells.map {
                ExerciseLoad(
                    amount: $0.amount, unit: $0.unit, representation: .perImplement, implementCount: dumbbellCount)
            }
        case .fixedBar:
            return fixedBars.map {
                ExerciseLoad(amount: $0.amount, unit: $0.unit, representation: .combined, implementCount: 1)
            }
        case .selectorizedMachine:
            return stride(from: 5, through: 150, by: 5).map {
                ExerciseLoad(amount: Decimal($0), unit: .kg, representation: .combined, implementCount: 1)
            }
        case .barbell, .plateLoadedMachine:
            return plateLoadOptions(unit: .lb, maximumPerSide: nil)
        case .bodyweight, .band, .cardio:
            return []
        }
    }

    public func loadOptions(for equipment: EquipmentDescription, dumbbellCount: Int = 1) -> [ExerciseLoad] {
        switch equipment.kind {
        case .barbell, .plateLoadedMachine:
            return plateLoadOptions(unit: equipment.unit, maximumPerSide: equipment.maximumAddedWeightPerSide)
        case .selectorizedMachine where equipment.availableLoads.isEmpty:
            return loadOptions(for: .selectorizedMachine)
        case .selectorizedMachine, .bodyweight, .band, .cardio:
            return equipment.availableLoads.map {
                ExerciseLoad(amount: $0, unit: equipment.unit, representation: .combined, implementCount: 1)
            }
        default:
            return loadOptions(for: equipment.kind, dumbbellCount: dumbbellCount)
        }
    }

    public func loadOptions(for equipment: EquipmentDescription, displayedLike current: ExerciseLoad) -> [ExerciseLoad]
    {
        loadOptions(for: equipment, dumbbellCount: current.implementCount).compactMap { option in
            let base = equipment.baseWeight.map { equipment.unit.converted($0, to: option.unit) }
            return try? option.displayed(as: current.representation, equipmentWeightInLoadUnit: base)
        }
    }

    private func plateLoadOptions(unit: ExerciseLoad.Unit, maximumPerSide: Decimal?) -> [ExerciseLoad] {
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
        return reachable.sorted().map {
            ExerciseLoad(
                amount: ExerciseLoad.Unit.kg.converted($0, to: unit), unit: unit, representation: .perSide,
                implementCount: 2)
        }
    }
}
