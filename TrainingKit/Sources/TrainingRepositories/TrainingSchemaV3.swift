import Foundation
import SwiftData

public enum TrainingSchemaV3: VersionedSchema {
    public static let versionIdentifier = Schema.Version(3, 0, 0)
    public static var models: [any PersistentModel.Type] {
        TrainingSchemaV2.models + [GymSelection.self]
    }

    @Model
    final class GymSelection {
        @Attribute(.unique) private var key = "activeGym"
        var gymID: UUID

        init(gymID: UUID) {
            self.gymID = gymID
        }
    }
}
