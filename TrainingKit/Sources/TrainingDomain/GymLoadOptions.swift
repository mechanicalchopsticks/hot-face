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
        case .barbell, .plateLoadedMachine, .bodyweight, .band, .cardio:
            return []
        }
    }
}
