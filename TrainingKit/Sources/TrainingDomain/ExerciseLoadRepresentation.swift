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

    private static func requiredEquipmentWeight(_ weight: Decimal?) throws -> Decimal {
        guard let weight else { throw ConversionError.missingEquipmentWeight }
        guard !weight.isNaN, weight >= 0 else { throw ConversionError.invalidLoad }
        return weight
    }
}
