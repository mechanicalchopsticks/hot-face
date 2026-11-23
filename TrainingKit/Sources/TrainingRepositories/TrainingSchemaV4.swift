import Foundation
import SwiftData
import TrainingDomain

extension CoordinatedModelStore {
    public init(trainingDirectory: URL) {
        self.init(
            schema: Schema(versionedSchema: TrainingSchemaV5.self),
            storeURL: trainingDirectory.appendingPathComponent("training.store"),
            lockURL: trainingDirectory.appendingPathComponent("training.lock"))
    }
}

public enum TrainingSchemaV4: VersionedSchema {
    public static let versionIdentifier = Schema.Version(4, 0, 0)
    public static var models: [any PersistentModel.Type] {
        TrainingSchemaV3.models + [InventoryRecord.self]
    }

    @Model
    final class InventoryRecord {
        @Attribute(.unique) var gymID: UUID
        var data: Data

        init(gymID: UUID, inventory: GymInventory) throws {
            self.gymID = gymID
            data = try JSONEncoder().encode(inventory)
        }

        var inventory: GymInventory {
            get throws { try JSONDecoder().decode(GymInventory.self, from: data) }
        }
    }
}
