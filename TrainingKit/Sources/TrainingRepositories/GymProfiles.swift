import Foundation
import SwiftData
import TrainingDomain

private typealias Gym = TrainingSchemaV1.Gym
private typealias GymSelection = TrainingSchemaV3.GymSelection

public struct GymProfile: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let equipment: [EquipmentDescription]
}

public struct GymCatalog: Sendable {
    public let gyms: [GymProfile]
    public let activeGymID: UUID?
}

public enum GymProfileError: Error, Equatable {
    case missingGym, emptyName, invalidLoads
}

extension CoordinatedModelStore {
    public func gymCatalog() throws -> GymCatalog {
        try withContext { try readGymCatalog(in: $0) }
    }

    public func createGym(name: String) throws -> GymCatalog {
        try validateGymName(name)
        return try updateGymCatalog { context in
            let isFirstGym = try context.fetchCount(FetchDescriptor<Gym>()) == 0
            let gym = try Gym(name: name)
            context.insert(gym)
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
            try setActiveGym(gymID, in: context)
        }
    }

    public func saveEquipment(_ equipment: EquipmentDescription, in gymID: UUID) throws -> GymCatalog {
        try validateGymName(equipment.name)
        let weights = equipment.availableLoads + [equipment.baseWeight].compactMap { $0 }
        guard weights.allSatisfy({ !$0.isNaN && $0 >= 0 }),
            equipment.plates.allSatisfy({ !$0.weight.isNaN && $0.weight > 0 && $0.count > 0 })
        else { throw GymProfileError.invalidLoads }
        return try updateGymCatalog { context in
            let profile = try gym(with: gymID, in: context)
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

private func readGymCatalog(in context: ModelContext) throws -> GymCatalog {
    let gyms = try context.fetch(FetchDescriptor<Gym>()).map {
        try GymProfile(id: $0.id, name: $0.name, equipment: $0.equipment)
    }
    return GymCatalog(gyms: gyms, activeGymID: try activeGym(in: context)?.gymID)
}

private func gym(with id: UUID, in context: ModelContext) throws -> Gym {
    let matching = FetchDescriptor<Gym>(predicate: #Predicate { $0.id == id })
    guard let gym = try context.fetch(matching).first else { throw GymProfileError.missingGym }
    return gym
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
