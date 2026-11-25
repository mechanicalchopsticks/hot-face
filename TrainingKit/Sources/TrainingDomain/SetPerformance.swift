import Foundation

public enum Effort: String, Codable, Sendable {
    case easy, hard
}

public struct SetPerformance: Codable, Equatable, Sendable {
    public var segments: [ExerciseSegment]
    public var load: ExerciseLoad?
    /// When sides differ, segments describes the first side and this records the second.
    public var secondSideSegments: [ExerciseSegment]?
    public var perSide: Bool
    public var isPartial: Bool

    public init(
        segments: [ExerciseSegment], load: ExerciseLoad? = nil, perSide: Bool = false,
        isPartial: Bool = false
    ) {
        self.segments = segments
        self.load = load
        self.perSide = perSide
        self.isPartial = isPartial
    }

    public mutating func updateTimedCompletion(prescribed: [ExerciseSegment]) {
        guard !prescribed.isEmpty, prescribed.allSatisfy({ if case .seconds = $0 { true } else { false } }) else {
            return
        }
        isPartial = segments != prescribed || (secondSideSegments ?? segments) != prescribed
    }

    /// Records a set as prescribed, including the numeric value of an estimate.
    public init(asPrescribed exercise: ExercisePrescription) {
        self.init(segments: exercise.segments, load: exercise.load.value, perSide: exercise.perSide)
    }
}
