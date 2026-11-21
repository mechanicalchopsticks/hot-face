import Foundation
import SwiftData
import TrainingDomain

// The encoded domain values are part of the V1 disk format, including ordered days and segments.
public enum TrainingSchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)
    public static var models: [any PersistentModel.Type] {
        [
            Gym.self, Routine.self, Cycle.self, Session.self, PerformedSet.self,
            Rating.self, Progression.self, PrescriptionChange.self, Note.self,
        ]
    }

    @Model
    public final class Gym {
        @Attribute(.unique) public private(set) var id: UUID
        public var name: String
        private var equipmentData: Data

        public init(id: UUID = UUID(), name: String, equipment: [EquipmentDescription] = []) throws {
            self.id = id
            self.name = name
            self.equipmentData = try JSONEncoder().encode(equipment)
        }

        public var equipment: [EquipmentDescription] {
            get throws { try JSONDecoder().decode([EquipmentDescription].self, from: equipmentData) }
        }

        public func replaceEquipment(_ equipment: [EquipmentDescription]) throws {
            equipmentData = try JSONEncoder().encode(equipment)
        }
    }

    @Model
    public final class Routine {
        @Attribute(.unique) public private(set) var id: UUID
        public private(set) var gymID: UUID
        public private(set) var revision: Int
        public var isArchived: Bool
        private var planData: Data

        public init(id: UUID = UUID(), gymID: UUID, plan: RoutinePlan) throws {
            self.id = id
            self.gymID = gymID
            self.revision = 1
            self.isArchived = false
            self.planData = try JSONEncoder().encode(plan)
        }

        public var plan: RoutinePlan {
            get throws { try JSONDecoder().decode(RoutinePlan.self, from: planData) }
        }

        public func replacePlan(_ newPlan: RoutinePlan) throws {
            guard try plan != newPlan else { return }
            planData = try JSONEncoder().encode(newPlan)
            revision += 1
        }
    }

    @Model
    public final class Cycle {
        @Attribute(.unique) public private(set) var id: UUID
        public private(set) var routineID: UUID
        public var orderedDayIDs: [UUID]
        public var completedDayIDs: [UUID]
        public var skippedDayIDs: [UUID]

        public init(routineID: UUID, orderedDayIDs: [UUID]) {
            self.id = UUID()
            self.routineID = routineID
            self.orderedDayIDs = orderedDayIDs
            self.completedDayIDs = []
            self.skippedDayIDs = []
        }
    }

    @Model
    public final class Session {
        @Attribute(.unique) public private(set) var id: UUID
        public private(set) var startedAt: Date
        public private(set) var cycleID: UUID?
        public private(set) var finishedAt: Date?
        public private(set) var isPartial: Bool
        public var skippedExerciseIDs: [UUID]
        private var prescriptionData: Data

        public init(id: UUID = UUID(), routine: Routine, gym: Gym, dayID: UUID, cycle: Cycle? = nil, startedAt: Date)
            throws
        {
            guard routine.gymID == gym.id else { throw SessionCreationError.mismatchedGym }
            if let cycle, cycle.routineID != routine.id { throw SessionCreationError.mismatchedCycle }
            let plan = try routine.plan
            guard let day = plan.days.first(where: { $0.id == dayID }) else {
                throw SessionCreationError.missingDay
            }
            let prescription = try SessionPrescription(
                gymID: gym.id, gymName: gym.name, routineID: routine.id, routineRevision: routine.revision,
                plan: plan, day: day, equipment: gym.equipment
            )
            self.prescriptionData = try JSONEncoder().encode(prescription)
            self.id = id
            self.startedAt = startedAt
            self.cycleID = cycle?.id
            self.isPartial = false
            self.skippedExerciseIDs = []
        }

        public var prescription: SessionPrescription {
            get throws { try JSONDecoder().decode(SessionPrescription.self, from: prescriptionData) }
        }

        public func finish(at date: Date, partial: Bool) {
            finishedAt = date
            isPartial = partial
        }
    }
}

public enum SessionCreationError: Error {
    case mismatchedGym, mismatchedCycle, missingDay
}
