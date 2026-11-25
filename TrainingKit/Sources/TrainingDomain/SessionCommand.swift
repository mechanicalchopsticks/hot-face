import Foundation

public enum RestAdjustment: String, Codable, Sendable {
    case shorten, extend, end

    public func applying(to deadline: Date, at now: Date) -> Date {
        switch self {
        case .shorten: max(now, deadline.addingTimeInterval(-15))
        case .extend: deadline.addingTimeInterval(15)
        case .end: now
        }
    }
}

/// Keep the command and session identifiers when retrying an action from the app or an extension.
public struct SessionCommand: Codable, Equatable, Sendable {
    public enum Action: Codable, Equatable, Sendable {
        case start(routineID: UUID, gymID: UUID, dayID: UUID, cycleID: UUID?)
        case completeSet(exerciseID: UUID, number: Int, performance: SetPerformance)
        case adjust(exerciseID: UUID, sets: Int, segments: [ExerciseSegment], load: PrescribedLoad, saveAsUsual: Bool)
        case moveExercise(id: UUID, toFront: Bool)
        case editSuperset(SupersetEdit, saveAsUsual: Bool)
        case insertExercise(sourceID: UUID, replacing: UUID?, saveAsUsual: Bool)
        case logSet(exerciseID: UUID, number: Int, performance: SetPerformance)
        case logCurrentSet(exerciseID: UUID, number: Int)
        case controlTimer(exerciseID: UUID, number: Int, expectedRevision: Int, action: WorkoutAction)
        case skipAndAdvance(exerciseID: UUID)
        case rateFinished(exerciseID: UUID, effort: Effort)
        case correctSet(id: UUID, performance: SetPerformance)
        case rate(exerciseID: UUID, effort: Effort)
        case skip(exerciseID: UUID)
        case adjustRest(setID: UUID, adjustment: RestAdjustment)
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
