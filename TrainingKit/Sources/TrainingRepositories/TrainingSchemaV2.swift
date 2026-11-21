import Foundation
import SwiftData
import TrainingDomain

extension CoordinatedModelStore {
    public init(trainingDirectory: URL) {
        self.init(
            schema: Schema(versionedSchema: TrainingSchemaV2.self),
            storeURL: trainingDirectory.appendingPathComponent("training.store"),
            lockURL: trainingDirectory.appendingPathComponent("training.lock"))
    }
}

public enum TrainingSchemaV2: VersionedSchema {
    public static let versionIdentifier = Schema.Version(2, 0, 0)
    public static var models: [any PersistentModel.Type] {
        TrainingSchemaV1.models + [CommandReceipt.self]
    }

    @Model
    final class CommandReceipt {
        @Attribute(.unique) private(set) var id: UUID
        private var commandData: Data

        init(_ command: SessionCommand) throws {
            id = command.id
            commandData = try JSONEncoder().encode(command)
        }

        var command: SessionCommand {
            get throws { try JSONDecoder().decode(SessionCommand.self, from: commandData) }
        }
    }
}
