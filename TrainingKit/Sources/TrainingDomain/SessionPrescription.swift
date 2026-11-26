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

    public struct RestSelection: Codable, Equatable, Sendable {
        public let setID: UUID
        public let blockID: UUID
        public let revision: UUID

        public init(setID: UUID, blockID: UUID) {
            self.setID = setID
            self.blockID = blockID
            self.revision = UUID()
        }
    }

    public var restSelection: RestSelection?
    public var restPrescription: RestPrescription?
    public var timer: WorkoutTimeline?
    /// Seed for new timers after a cancelled start, including when the exercise is postponed.
    public var timerStartRevision: Int?
    public var summaryPending: Bool?
    public var restOverride: RestOverride?
    public var temporaryExerciseIDs: Set<UUID>?
    /// Set numbers already recorded for each exercise when its current superset was formed.
    public var setsBeforeSuperset: [UUID: Set<Int>]?
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
    public func roundNumber(for exercise: ExercisePrescription, set: Int) -> Int {
        guard exercise.supersetID != nil, let previous = setsBeforeSuperset?[exercise.id] else { return set }
        if previous.contains(set) { return 0 }
        return set - previous.count { $0 < set }
    }

    public func roundCount(in supersetID: UUID) -> Int {
        day.exercises.filter { $0.supersetID == supersetID }.map {
            ($0.sets ?? 0) - (setsBeforeSuperset?[$0.id]?.count ?? 0)
        }.max() ?? 0
    }

    public func restDuration(
        after exercise: ExercisePrescription, completedSet: Int,
        before nextExercise: ExercisePrescription, nextSet: Int
    ) -> TimeInterval {
        if let supersetID = exercise.supersetID {
            let settings = day.supersetRests[supersetID]
            if supersetID == nextExercise.supersetID {
                let completedRound = roundNumber(for: exercise, set: completedSet)
                let nextRound = roundNumber(for: nextExercise, set: nextSet)
                return nextRound > completedRound ? settings?.restBetweenRounds ?? restBetweenSets : 0
            }
            return settings?.restAfterSuperset ?? restBetweenExercises
        }
        if exercise.id == nextExercise.id { return exercise.restBetweenSets ?? restBetweenSets }
        return exercise.restAfterExercise ?? restBetweenExercises
    }

}
