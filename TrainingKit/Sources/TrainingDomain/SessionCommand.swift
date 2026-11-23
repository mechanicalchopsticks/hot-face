import Foundation

/// Keep the command and session identifiers when retrying an action from the app or an extension.
public struct SessionCommand: Codable, Equatable, Sendable {
    public enum Action: Codable, Equatable, Sendable {
        case start(routineID: UUID, gymID: UUID, dayID: UUID, cycleID: UUID?)
        case completeSet(exerciseID: UUID, number: Int, performance: SetPerformance)
        case adjust(exerciseID: UUID, sets: Int, segments: [ExerciseSegment], load: PrescribedLoad, saveAsUsual: Bool)
        case correctSet(id: UUID, performance: SetPerformance)
        case rate(exerciseID: UUID, effort: Effort)
        case skip(exerciseID: UUID)
        case finish
    }

    public let id: UUID
    public let sessionID: UUID
    public let action: Action

    public init(id: UUID = UUID(), sessionID: UUID, action: Action) {
        self.id = id
        self.sessionID = sessionID
        self.action = action
    }
}
