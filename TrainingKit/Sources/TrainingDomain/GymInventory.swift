import Foundation

public struct InventoryWeight: Codable, Hashable, Sendable {
    public var amount: Decimal
    public var unit: ExerciseLoad.Unit

    public init(_ amount: Decimal, _ unit: ExerciseLoad.Unit) {
        self.amount = amount
        self.unit = unit
    }
}

public struct GymInventory: Codable, Equatable, Sendable {
    public enum Kind: CaseIterable, Sendable { case plates, dumbbells, fixedBars }

    public private(set) var plates: [InventoryWeight] = []
    public private(set) var dumbbells: [InventoryWeight] = []
    public private(set) var fixedBars: [InventoryWeight] = []

    public init() {}

    public subscript(kind: Kind) -> [InventoryWeight] {
        get {
            switch kind {
            case .plates: plates
            case .dumbbells: dumbbells
            case .fixedBars: fixedBars
            }
        }
        set {
            switch kind {
            case .plates: plates = newValue
            case .dumbbells: dumbbells = newValue
            case .fixedBars: fixedBars = newValue
            }
        }
    }

    public static let initial: Self = {
        var inventory = Self()
        inventory.plates = [2.5, 5, 10, 25, 35, 45].map { InventoryWeight($0, .lb) }
        inventory.dumbbells =
            [2.5, 5, 10, 15, 20, 25, 30, 35, 40, 50, 60, 70, 80, 90, 100].map { InventoryWeight($0, .lb) }
            + [5, 7.5, 10, 12.5].map { InventoryWeight($0, .kg) }
        inventory.fixedBars = [10, 15, 20, 25, 30, 35, 40, 50].map { InventoryWeight($0, .kg) }
        return inventory
    }()
}
