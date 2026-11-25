import Foundation

extension ExerciseLoad {
    public enum ConversionError: Error, Equatable {
        case incompatibleRepresentation
        case missingEquipmentWeight
        case invalidLoad
    }

    /// Presents the same load in another representation without editing the prescription.
    public func displayed(
        as target: Representation, equipmentWeightInLoadUnit: Decimal? = nil
    ) throws -> ExerciseLoad {
        guard !amount.isNaN, amount >= 0 else { throw ConversionError.invalidLoad }
        guard target != representation else { return self }

        var display = self
        switch (representation, target) {
        case (.perImplement, .combined), (.combined, .perImplement):
            guard (1...2).contains(implementCount) else { throw ConversionError.invalidLoad }
            let count = Decimal(implementCount)
            display.amount = target == .combined ? amount * count : amount / count
        case (.perSide, .totalAdded):
            display.amount = amount * 2
        case (.totalAdded, .perSide):
            display.amount = amount / 2
        case (.perSide, .includingEquipment), (.totalAdded, .includingEquipment):
            let weight = try Self.requiredEquipmentWeight(equipmentWeightInLoadUnit)
            let added = representation == .perSide ? amount * 2 : amount
            display.amount = added + weight
        case (.includingEquipment, .perSide), (.includingEquipment, .totalAdded):
            let weight = try Self.requiredEquipmentWeight(equipmentWeightInLoadUnit)
            let added = amount - weight
            display.amount = target == .perSide ? added / 2 : added
        default:
            throw ConversionError.incompatibleRepresentation
        }
        guard !display.amount.isNaN, display.amount >= 0 else { throw ConversionError.invalidLoad }
        display.representation = target
        return display
    }

    /// Calculates percentage change using only the added weight per side. Zero has no percentage change.
    public func addedWeightPercentageChange(to target: ExerciseLoad, equipmentWeight: InventoryWeight? = nil) throws
        -> Decimal?
    {
        let comparisonUnit = unit == target.unit && (equipmentWeight?.unit ?? unit) == unit ? unit : .kg
        let equipmentAmount = equipmentWeight.map { $0.unit.converted($0.amount, to: comparisonUnit) }

        func addedPerSide(_ load: ExerciseLoad) throws -> Decimal {
            var normalized = load
            normalized.amount = load.unit.converted(load.amount, to: comparisonUnit)
            normalized.unit = comparisonUnit
            return try normalized.displayed(as: .perSide, equipmentWeightInLoadUnit: equipmentAmount).amount
        }

        let currentWeight = try addedPerSide(self)
        let targetWeight = try addedPerSide(target)
        guard currentWeight > 0 else { return nil }
        return (targetWeight - currentWeight) * 100 / currentWeight
    }

    private static func requiredEquipmentWeight(_ weight: Decimal?) throws -> Decimal {
        guard let weight else { throw ConversionError.missingEquipmentWeight }
        guard !weight.isNaN, weight >= 0 else { throw ConversionError.invalidLoad }
        return weight
    }
}

extension ExerciseLoad.Unit {
    private static let kilogramsPerPound = Decimal(45_359_237) / 100_000_000

    public func converted(_ amount: Decimal, to target: Self) -> Decimal {
        guard self != target else { return amount }
        return self == .lb ? amount * Self.kilogramsPerPound : amount / Self.kilogramsPerPound
    }
}

extension ExerciseLoad {
    /// Total external load, excluding the implement's base weight for plate-loaded equipment.
    public func addedKilograms(equipment: EquipmentDescription?) throws -> Decimal {
        let total: Representation
        switch representation {
        case .perSide, .totalAdded, .includingEquipment: total = .totalAdded
        case .perImplement, .combined: total = .combined
        }
        let base = equipment.flatMap { item in item.baseWeight.map { item.unit.converted($0, to: unit) } }
        let load = try displayed(as: total, equipmentWeightInLoadUnit: base)
        return unit.converted(load.amount, to: .kg)
    }
}
