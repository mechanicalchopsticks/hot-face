import Foundation

public enum Effort: String, Codable, Sendable {
    case easy, hard
}

public struct SetPerformance: Codable, Equatable, Sendable {
    public var segments: [ExerciseSegment]
    public var load: ExerciseLoad?
    public var perSide: Bool
    public var isPartial: Bool

    public init(segments: [ExerciseSegment], load: ExerciseLoad? = nil, perSide: Bool = false,
                isPartial: Bool = false) {
        self.segments = segments
        self.load = load
        self.perSide = perSide
        self.isPartial = isPartial
    }
}
