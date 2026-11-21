import Foundation

public struct EquipmentDescription: Identifiable, Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case dumbbell, barbell, fixedBar, selectorizedMachine, plateLoadedMachine, bodyweight, band, cardio
    }

    public let id: UUID
    public var name: String
    public var kind: Kind
    public var unit: ExerciseLoad.Unit
    public var availableLoads: [Decimal] = []
    public var baseWeight: Decimal?
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
    public let day: RoutineDay
    public let equipment: [EquipmentDescription]
    public let restBetweenSets: TimeInterval
    public let restBetweenExercises: TimeInterval

    public init(gymID: UUID, gymName: String, routineID: UUID, routineRevision: Int,
                plan: RoutinePlan, day: RoutineDay, equipment: [EquipmentDescription]) {
        self.gymID = gymID
        self.gymName = gymName
        self.routineID = routineID
        self.routineRevision = routineRevision
        self.routineName = plan.name
        self.day = day
        let equipmentIDs = Set(day.exercises.compactMap(\.equipmentID))
        self.equipment = equipment.filter { equipmentIDs.contains($0.id) }
        self.restBetweenSets = plan.restBetweenSets
        self.restBetweenExercises = plan.restBetweenExercises
    }
}
