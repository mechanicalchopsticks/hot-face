import Foundation

public struct EquipmentDescription: Identifiable, Codable, Equatable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case dumbbell, barbell, fixedBar, selectorizedMachine, plateLoadedMachine, bodyweight, band, cardio
    }

    public let id: UUID
    public var name: String
    public var station: String?
    public var kind: Kind
    public var unit: ExerciseLoad.Unit
    public var availableLoads: [Decimal] = []
    public var baseWeight: Decimal?
    public var maximumAddedWeightPerSide: Decimal?
    public var plates: [PlateInventory] = []

    public init(id: UUID = UUID(), name: String, kind: Kind, unit: ExerciseLoad.Unit) {
        self.id = id
        self.name = name
        self.kind = kind
        self.unit = unit
    }
}

public struct PlateInventory: Codable, Equatable, Sendable {
    public var weight: Decimal
    public var count: Int

    public init(weight: Decimal, count: Int) {
        self.weight = weight
        self.count = count
    }
}

public struct SessionPrescription: Codable, Equatable, Sendable {
    public let gymID: UUID
    public let gymName: String
    public let routineID: UUID
    public let routineRevision: Int
    public let routineName: String
    public var day: RoutineDay
    public struct RestPrescription: Codable, Equatable, Sendable {
        public let setID: UUID
        public let segments: [ExerciseSegment]

        public init(setID: UUID, segments: [ExerciseSegment]) {
            self.setID = setID
            self.segments = segments
        }
    }

    public struct RestOverride: Codable, Equatable, Sendable {
        public let setID: UUID
        public let endsAt: Date

        public init(setID: UUID, endsAt: Date) {
            self.setID = setID
            self.endsAt = endsAt
        }
    }

    public var restPrescription: RestPrescription?
    public var timer: WorkoutTimeline?
    public var restOverride: RestOverride?
    public var temporaryExerciseIDs: Set<UUID>?
    public var equipment: [EquipmentDescription]
    public let restBetweenSets: TimeInterval
    public let restBetweenExercises: TimeInterval

    public init(
        gymID: UUID, gymName: String, routineID: UUID, routineRevision: Int,
        plan: RoutinePlan, day: RoutineDay, equipment: [EquipmentDescription]
    ) {
        self.gymID = gymID
        self.gymName = gymName
        self.routineID = routineID
        self.routineRevision = routineRevision
        self.routineName = plan.name
        var snapshot = day
        for index in snapshot.exercises.indices {
            snapshot.exercises[index].sets = plan.setCount(for: day.exercises[index])
        }
        self.day = snapshot
        let equipmentIDs = Set(day.exercises.compactMap(\.equipmentID))
        self.equipment = equipment.filter { equipmentIDs.contains($0.id) }
        self.restBetweenSets = plan.restBetweenSets
        self.restBetweenExercises = plan.restBetweenExercises
    }
    public func restDuration(
        after exercise: ExercisePrescription, completedSet: Int,
        before nextExercise: ExercisePrescription, nextSet: Int
    ) -> TimeInterval {
        if let supersetID = exercise.supersetID {
            let settings = day.supersetRests[supersetID]
            if supersetID == nextExercise.supersetID {
                return nextSet == completedSet ? 0 : settings?.restBetweenRounds ?? restBetweenSets
            }
            return settings?.restAfterSuperset ?? restBetweenExercises
        }
        if exercise.id == nextExercise.id { return exercise.restBetweenSets ?? restBetweenSets }
        return exercise.restAfterExercise ?? restBetweenExercises
    }

}
