import Foundation

public enum WorkoutAction: String, Sendable {
    case start, pause, resume, complete
}

public enum WorkoutPhase: Equatable, Sendable {
    case ready, preparation, exercise, paused, rest
}

public struct WorkoutTimeline: Codable, Hashable, Sendable {
    private static let preparationDuration: TimeInterval = 3

    public let setNumber: Int
    public private(set) var revision = 0
    public private(set) var exerciseStart: Date?
    public private(set) var exerciseEnd: Date?
    public private(set) var restEnd: Date?
    public private(set) var pausedSeconds: TimeInterval?

    public init(setNumber: Int = 1) {
        self.setNumber = setNumber
    }

    public func phase(at date: Date) -> WorkoutPhase {
        if pausedSeconds != nil { return .paused }
        if let exerciseStart, date < exerciseStart { return .preparation }
        if let exerciseEnd, date < exerciseEnd { return .exercise }
        if let restEnd, date < restEnd { return .rest }
        return .ready
    }

    public func nextBoundary(after date: Date) -> Date? {
        [exerciseStart, exerciseEnd, restEnd].compactMap { $0 }.first { $0 > date }
    }

    public func currentSet(at date: Date) -> Int {
        if let restEnd, date >= restEnd { return setNumber + 1 }
        return setNumber
    }

    public func applying(
        _ action: WorkoutAction, expectedRevision: Int, expectedSet: Int,
        exerciseDuration: TimeInterval, restDuration: TimeInterval, clock: any WorkoutClock
    ) -> Self? {
        let now = clock.now
        guard revision == expectedRevision, currentSet(at: now) == expectedSet,
            exerciseDuration.isFinite, exerciseDuration > 0,
            restDuration.isFinite, restDuration >= 0
        else { return nil }
        let phase = phase(at: now)
        var next = Self(setNumber: expectedSet)
        next.revision = revision + 1
        switch (action, phase) {
        case (.start, .ready), (.resume, .paused):
            let start = now.addingTimeInterval(Self.preparationDuration)
            let end = start.addingTimeInterval(pausedSeconds ?? exerciseDuration)
            next.exerciseStart = start
            next.exerciseEnd = end
            next.restEnd = end.addingTimeInterval(restDuration)
        case (.pause, .preparation), (.pause, .exercise):
            guard let exerciseStart, let exerciseEnd else { return nil }
            next.pausedSeconds = exerciseEnd.timeIntervalSince(max(now, exerciseStart))
        case (.complete, .ready), (.complete, .preparation), (.complete, .exercise), (.complete, .paused):
            next.restEnd = now.addingTimeInterval(restDuration)
        default:
            return nil
        }
        return next
    }
}
