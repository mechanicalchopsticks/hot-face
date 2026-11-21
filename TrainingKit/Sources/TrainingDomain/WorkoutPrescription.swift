import Foundation

public struct ExerciseLoad: Codable, Equatable, Sendable {
    public enum Unit: String, Codable, Sendable { case kg, lb }
    public enum Representation: String, Codable, Sendable {
        case perImplement, combined, perSide, totalAdded, includingEquipment
    }

    public var amount: Decimal
    public var unit: Unit
    public var representation: Representation
    public var implementCount: Int

    public init(amount: Decimal, unit: Unit, representation: Representation, implementCount: Int) {
        self.amount = amount
        self.unit = unit
        self.representation = representation
        self.implementCount = implementCount
    }
}

public enum PrescribedLoad: Codable, Equatable, Sendable {
    case undefined
    case estimated(ExerciseLoad)
    case confirmed(ExerciseLoad)
}

public enum ExerciseSegment: Codable, Equatable, Sendable {
    case repetitions(Int)
    case seconds(Int)
}

public struct ExercisePrescription: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var group: String?
    public var variant: String?
    public var instructions: String?
    public var equipmentID: UUID?
    public var station: String?
    public var sets: Int
    public var segments: [ExerciseSegment]
    public var perSide = false
    public var load: PrescribedLoad = .undefined
    public var restBetweenSets: TimeInterval?
    public var restAfterExercise: TimeInterval?
    public var supersetID: UUID?

    public init(id: UUID = UUID(), name: String, sets: Int, segments: [ExerciseSegment]) {
        self.id = id
        self.name = name
        self.sets = sets
        self.segments = segments
    }
}

public struct RoutineDay: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var exercises: [ExercisePrescription]

    public init(id: UUID = UUID(), name: String, exercises: [ExercisePrescription]) {
        self.id = id
        self.name = name
        self.exercises = exercises
    }
}

public struct RoutinePlan: Codable, Equatable, Sendable {
    public var name: String
    public var days: [RoutineDay]
    public var restBetweenSets: TimeInterval
    public var restBetweenExercises: TimeInterval

    public init(
        name: String, days: [RoutineDay], restBetweenSets: TimeInterval = 105,
        restBetweenExercises: TimeInterval = 135
    ) {
        self.name = name
        self.days = days
        self.restBetweenSets = restBetweenSets
        self.restBetweenExercises = restBetweenExercises
    }
}
