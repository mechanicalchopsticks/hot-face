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

    public var value: ExerciseLoad? {
        switch self {
        case .undefined: nil
        case .estimated(let load), .confirmed(let load): load
        }
    }
}

public enum ExerciseSegment: Codable, Equatable, Sendable {
    case repetitions(Int)
    case seconds(Int)
    case toFailure
}

public enum ResistanceBandColor: String, Codable, CaseIterable, Sendable {
    case red, orange, yellow, green, blue, purple, brown, pink, lightBlue, white, lightGray, darkGray, black
}

public struct ExercisePrescription: Identifiable, Codable, Equatable, Sendable {
    public private(set) var id: UUID
    public var name: String
    public var group: String?
    public var variant: String?
    public var instructions: String?
    public var equipmentID: UUID?
    public var bandColor: ResistanceBandColor?
    public var station: String?
    /// A missing count inherits the routine default. Older payloads always contain an explicit count.
    public var sets: Int?
    public var segments: [ExerciseSegment]
    public var perSide = false
    public var load: PrescribedLoad = .undefined
    public var restBetweenSets: TimeInterval?
    public var restAfterExercise: TimeInterval?
    public var supersetID: UUID?

    public init(id: UUID = UUID(), name: String, sets: Int? = nil, segments: [ExerciseSegment]) {
        self.id = id
        self.name = name
        self.sets = sets
        self.segments = segments
    }

    fileprivate func copied(supersetID: UUID?) -> Self {
        var copy = self
        copy.id = UUID()
        copy.supersetID = supersetID
        return copy
    }

}

public struct RoutineDay: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var exercises: [ExercisePrescription]
    public private(set) var groupNames: [String]

    public init(id: UUID = UUID(), name: String, exercises: [ExercisePrescription], groupNames: [String] = []) {
        self.id = id
        self.name = name
        self.exercises = exercises
        self.groupNames = groupNames
        for index in self.exercises.indices {
            let group = registerGroup(exercises[index].group)
            self.exercises[index].group = group
        }
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try values.decode(UUID.self, forKey: .id),
            name: try values.decode(String.self, forKey: .name),
            exercises: try values.decode([ExercisePrescription].self, forKey: .exercises),
            groupNames: try values.decodeIfPresent([String].self, forKey: .groupNames) ?? [])
    }

    public mutating func assignGroup(_ name: String?, to exerciseID: UUID) {
        guard let index = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        let group = registerGroup(name)
        exercises[index].group = group
    }

    private mutating func registerGroup(_ name: String?) -> String? {
        guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return nil }
        if let existing = groupNames.first(where: { $0.compare(name, options: .caseInsensitive) == .orderedSame }) {
            return existing
        }
        groupNames.append(name)
        return name
    }
}

public struct RoutinePlan: Codable, Equatable, Sendable {
    public var name: String
    public var days: [RoutineDay]
    public var defaultSets: Int
    public var restBetweenSets: TimeInterval
    public var restBetweenExercises: TimeInterval

    public init(
        name: String, days: [RoutineDay], defaultSets: Int = 4, restBetweenSets: TimeInterval = 105,
        restBetweenExercises: TimeInterval = 135
    ) {
        self.name = name
        self.days = days
        self.defaultSets = defaultSets
        self.restBetweenSets = restBetweenSets
        self.restBetweenExercises = restBetweenExercises
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decode(String.self, forKey: .name)
        days = try values.decode([RoutineDay].self, forKey: .days)
        defaultSets = try values.decodeIfPresent(Int.self, forKey: .defaultSets) ?? 1
        restBetweenSets = try values.decode(TimeInterval.self, forKey: .restBetweenSets)
        restBetweenExercises = try values.decode(TimeInterval.self, forKey: .restBetweenExercises)
    }

    public func copiedForNewRoutine() -> RoutinePlan {
        var copy = self
        var supersets: [UUID: UUID] = [:]
        copy.days = days.map { day in
            RoutineDay(
                name: day.name,
                exercises: day.exercises.map { exercise in
                    let group = exercise.supersetID.map { id in
                        if let existing = supersets[id] { return existing }
                        let newID = UUID()
                        supersets[id] = newID
                        return newID
                    }
                    return exercise.copied(supersetID: group)
                }, groupNames: day.groupNames)
        }
        return copy
    }

    public func setCount(for exercise: ExercisePrescription) -> Int {
        exercise.sets ?? defaultSets
    }
}
