import Foundation
import SwiftData
import TrainingDomain

private typealias Gym = TrainingSchemaV1.Gym
private typealias InventoryRecord = TrainingSchemaV4.InventoryRecord
private typealias GymSelection = TrainingSchemaV3.GymSelection

public struct GymProfile: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let inventory: GymInventory
    public let equipment: [EquipmentDescription]

    public func loadOptions(for equipmentID: UUID, dumbbellCount: Int = 1) -> [ExerciseLoad] {
        guard let item = equipment.first(where: { $0.id == equipmentID }) else { return [] }
        return inventory.loadOptions(for: item, dumbbellCount: dumbbellCount)
    }
}

public struct GymCatalog: Sendable {
    public let gyms: [GymProfile]
    public let activeGymID: UUID?
}

public enum GymProfileError: Error, Equatable {
    case missingGym, emptyName, invalidLoads, invalidReplacement
}

extension CoordinatedModelStore {
    public func gymCatalog() throws -> GymCatalog {
        try updateGymCatalog { _ in }
    }

    public func createGym(name: String) throws -> GymCatalog {
        try validateGymName(name)
        return try updateGymCatalog { context in
            let isFirstGym = try availableGyms(in: context).isEmpty
            let gym = try Gym(name: name)
            context.insert(gym)
            context.insert(try InventoryRecord(gymID: gym.id, inventory: .initial))
            if isFirstGym { try setActiveGym(gym.id, in: context) }
        }
    }

    public func renameGym(_ gymID: UUID, name: String) throws -> GymCatalog {
        try validateGymName(name)
        return try updateGymCatalog { context in
            try gym(with: gymID, in: context).name = name
        }
    }

    public func selectGym(_ gymID: UUID) throws -> GymCatalog {
        try updateGymCatalog { context in
            _ = try gym(with: gymID, in: context)
            let previousID = try selectedGymID(in: context)
            guard previousID != gymID else { return }
            try requireClosedSession(in: context)
            for routine in try unarchivedRoutines(in: context) where previousID != nil || routine.gymID != gymID {
                routine.isArchived = true
            }
            try setActiveGym(gymID, in: context)
        }
    }

    public func checkGymDeletion(_ gymID: UUID) throws {
        try withContext { try requireClosedSession(inGym: gymID, context: $0) }
    }

    public func deleteGym(_ gymID: UUID, replacingWith replacement: UUID? = nil) throws -> GymCatalog {
        try updateGymCatalog { context in
            let gyms = try availableGyms(in: context)
            guard gyms.contains(where: { $0.id == gymID }) else { throw GymProfileError.missingGym }
            try requireClosedSession(inGym: gymID, context: context)
            let selection = try activeGym(in: context)
            if selection?.gymID == gymID {
                if gyms.count > 1 {
                    guard let replacement, replacement != gymID, gyms.contains(where: { $0.id == replacement })
                    else { throw GymProfileError.invalidReplacement }
                    selection?.gymID = replacement
                } else if let selection {
                    guard replacement == nil else { throw GymProfileError.invalidReplacement }
                    context.delete(selection)
                }
            } else if replacement != nil {
                throw GymProfileError.invalidReplacement
            }
            for routine in try unarchivedRoutines(in: context) where routine.gymID == gymID {
                routine.isArchived = true
            }
            context.insert(TrainingSchemaV5.RetiredGym(gymID: gymID))
        }
    }

    public func saveInventory(_ weights: [InventoryWeight], for kind: GymInventory.Kind, in gymID: UUID) throws
        -> GymCatalog
    {
        guard weights.allSatisfy({ !$0.amount.isNaN && (kind == .plates ? $0.amount > 0 : $0.amount >= 0) }),
            Set(weights).count == weights.count
        else { throw GymProfileError.invalidLoads }
        return try updateGymCatalog { context in
            let gym = try gym(with: gymID, in: context)
            let record = try inventoryRecord(for: gym, in: context)
            var inventory = try record.inventory
            inventory[kind] = weights
            record.data = try JSONEncoder().encode(inventory)
        }
    }

    public func saveEquipment(_ equipment: EquipmentDescription, in gymID: UUID) throws -> GymCatalog {
        try validateGymName(equipment.name)
        let weights =
            equipment.availableLoads + [equipment.baseWeight, equipment.maximumAddedWeightPerSide].compactMap { $0 }
        guard weights.allSatisfy({ !$0.isNaN && $0 >= 0 }),
            equipment.plates.allSatisfy({ !$0.weight.isNaN && $0.weight > 0 && $0.count > 0 })
        else { throw GymProfileError.invalidLoads }
        return try updateGymCatalog { context in
            let profile = try gym(with: gymID, in: context)
            let record = try inventoryRecord(for: profile, in: context)
            var equipment = equipment
            var shared = try record.inventory
            transferSharedWeights(from: &equipment, to: &shared)
            record.data = try JSONEncoder().encode(shared)
            var inventory = try profile.equipment
            if let index = inventory.firstIndex(where: { $0.id == equipment.id }) {
                inventory[index] = equipment
            } else {
                inventory.append(equipment)
            }
            try profile.replaceEquipment(inventory)
        }
    }

    private func updateGymCatalog(_ update: (ModelContext) throws -> Void) throws -> GymCatalog {
        try withContext { context in
            try update(context)
            let catalog = try readGymCatalog(in: context)
            try context.save()
            return catalog
        }
    }
}

private func requireClosedSession(inGym gymID: UUID, context: ModelContext) throws {
    let query = FetchDescriptor<TrainingSchemaV1.Session>(predicate: #Predicate { $0.finishedAt == nil })
    for session in try context.fetch(query) where try session.prescription.gymID == gymID {
        throw RoutineEditorError.openSession(session.id)
    }
}

private func availableGyms(in context: ModelContext) throws -> [Gym] {
    let retired = Set(try context.fetch(FetchDescriptor<TrainingSchemaV5.RetiredGym>()).map(\.gymID))
    return try context.fetch(FetchDescriptor<Gym>()).filter { !retired.contains($0.id) }
}

private func readGymCatalog(in context: ModelContext) throws -> GymCatalog {
    let gyms = try availableGyms(in: context).map {
        let inventory = try inventoryRecord(for: $0, in: context).inventory
        return try GymProfile(id: $0.id, name: $0.name, inventory: inventory, equipment: $0.equipment)
    }
    return GymCatalog(gyms: gyms, activeGymID: try activeGym(in: context)?.gymID)
}

private func gym(with id: UUID, in context: ModelContext) throws -> Gym {
    guard let gym = try availableGyms(in: context).first(where: { $0.id == id }) else {
        throw GymProfileError.missingGym
    }
    return gym
}

func selectedGymID(in context: ModelContext) throws -> UUID? {
    try activeGym(in: context)?.gymID
}

private func activeGym(in context: ModelContext) throws -> GymSelection? {
    try context.fetch(FetchDescriptor<GymSelection>()).first
}

private func setActiveGym(_ gymID: UUID, in context: ModelContext) throws {
    if let selection = try activeGym(in: context) {
        selection.gymID = gymID
    } else {
        context.insert(GymSelection(gymID: gymID))
    }
}

private func validateGymName(_ name: String) throws {
    guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw GymProfileError.emptyName
    }
}

// A missing row identifies a pre-V4 gym. Insert the row and transfer its legacy
// entries under the same store lock and save, even when all three lists are empty.
private func inventoryRecord(for gym: Gym, in context: ModelContext) throws -> InventoryRecord {
    let id = gym.id
    let request = FetchDescriptor<InventoryRecord>(predicate: #Predicate { $0.gymID == id })
    if let record = try context.fetch(request).first { return record }

    var inventory = GymInventory()
    var equipment = try gym.equipment
    for index in equipment.indices {
        transferSharedWeights(from: &equipment[index], to: &inventory)
    }
    try gym.replaceEquipment(equipment)
    let record = try InventoryRecord(gymID: id, inventory: inventory)
    context.insert(record)
    return record
}

private func transferSharedWeights(from item: inout EquipmentDescription, to inventory: inout GymInventory) {
    func merge(_ amounts: [Decimal], into kind: GymInventory.Kind) {
        for amount in amounts {
            let weight = InventoryWeight(amount, item.unit)
            if !inventory[kind].contains(weight) { inventory[kind].append(weight) }
        }
    }
    merge(item.plates.map(\.weight), into: .plates)
    item.plates = []
    if item.kind == .dumbbell || item.kind == .fixedBar {
        merge(item.availableLoads, into: item.kind == .dumbbell ? .dumbbells : .fixedBars)
        item.availableLoads = []
    }
}
