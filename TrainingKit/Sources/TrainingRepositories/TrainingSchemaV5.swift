import Foundation
import SwiftData

public enum TrainingSchemaV5: VersionedSchema {
    public static let versionIdentifier = Schema.Version(5, 0, 0)
    public static var models: [any PersistentModel.Type] {
        TrainingSchemaV4.models + [RetiredGym.self]
    }

    // Keep the original gym and its equipment addressable by archived routine IDs.
    @Model
    final class RetiredGym {
        @Attribute(.unique) var gymID: UUID

        init(gymID: UUID) { self.gymID = gymID }
    }
}
