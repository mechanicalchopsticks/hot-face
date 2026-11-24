import Foundation

public enum WorkoutAction: String, Codable, Sendable {
    case start, pause, resume, complete
}

public enum WorkoutPhase: Equatable, Sendable {
    case ready, preparation, exercise, paused, holdPause, rest
}

public struct WorkoutTimeline: Codable, Hashable, Sendable {
    private static let preparationDuration: TimeInterval = 3

    public let setNumber: Int
    public private(set) var revision = 0
    public private(set) var exerciseStart: Date?
    public private(set) var exerciseEnd: Date?
    public private(set) var restEnd: Date?
    public private(set) var pausedSeconds: TimeInterval?

    private var completedHolds: [Int]?
    private var firstSideHolds: [Int]?
    public private(set) var holdAvailableAt: Date?

    public var sideNumber: Int { firstSideHolds == nil ? 1 : 2 }
    public var holdNumber: Int { (completedHolds?.count ?? 0) + 1 }

    public init(setNumber: Int = 1) {
        self.setNumber = setNumber
    }

    public func phase(at date: Date) -> WorkoutPhase {
        if pausedSeconds != nil { return .paused }
        if let holdAvailableAt, date < holdAvailableAt { return .holdPause }
        if let exerciseStart, date < exerciseStart { return .preparation }
        if let exerciseEnd, date < exerciseEnd { return .exercise }
        if let restEnd, date < restEnd { return .rest }
        return .ready
    }

    public func nextBoundary(after date: Date) -> Date? {
        guard pausedSeconds == nil else { return nil }
        return [holdAvailableAt, exerciseStart, exerciseEnd, restEnd].compactMap { $0 }.first { $0 > date }
    }

    /// Remaining work excludes preparation and time spent paused.
    public func remainingExerciseTime(at date: Date) -> TimeInterval {
        if let pausedSeconds { return pausedSeconds }
        guard let exerciseStart, let exerciseEnd else { return 0 }
        return max(0, exerciseEnd.timeIntervalSince(max(date, exerciseStart)))
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
        next.completedHolds = completedHolds
        next.firstSideHolds = firstSideHolds
        switch (action, phase) {
        case (.start, .ready), (.resume, .paused):
            let start = max(now, holdAvailableAt ?? now).addingTimeInterval(Self.preparationDuration)
            let end = start.addingTimeInterval(pausedSeconds ?? exerciseDuration)
            next.holdAvailableAt = holdAvailableAt
            next.exerciseStart = start
            next.exerciseEnd = end
            next.restEnd = end.addingTimeInterval(restDuration)
        case (.pause, .preparation), (.pause, .exercise),
            (.pause, .holdPause):
            guard exerciseEnd != nil else { return nil }
            next.holdAvailableAt = holdAvailableAt
            next.pausedSeconds = remainingExerciseTime(at: now)
        case (.complete, .ready), (.complete, .preparation), (.complete, .exercise), (.complete, .paused),
            (.complete, .holdPause):
            next.restEnd = now.addingTimeInterval(restDuration)
        default:
            return nil
        }
        return next
    }

    /// Projects exactly the transition the repository will save when the current hold expires.
    public func followingHold(in exercise: ExercisePrescription) -> Self? {
        guard let end = exerciseEnd, let durations = exercise.timedHolds, holdNumber <= durations.count else {
            return nil
        }
        if holdNumber == durations.count {
            return followingSide(in: exercise, at: end)
        }
        var next = Self(setNumber: setNumber)
        next.revision = revision + 1
        next.firstSideHolds = firstSideHolds
        next.completedHolds = (completedHolds ?? []) + [durations[holdNumber - 1]]
        let start = end.addingTimeInterval(TimeInterval(exercise.pauseBetweenHolds ?? 0))
        next.holdAvailableAt = start
        if exercise.automaticallyStartsHolds == true {
            next.exerciseStart = start
            next.exerciseEnd = start.addingTimeInterval(TimeInterval(durations[holdNumber]))
        }
        return next
    }

    /// Each side requires an explicit start, including when the holds within a side restart automatically.
    public func followingSide(in exercise: ExercisePrescription, at date: Date) -> Self? {
        guard exercise.perSide, firstSideHolds == nil, let actual = performedHolds(in: exercise, at: date) else {
            return nil
        }
        var next = Self(setNumber: setNumber)
        next.revision = revision + 1
        next.firstSideHolds = actual
        return next
    }

    public func performance(in exercise: ExercisePrescription, at date: Date) -> SetPerformance? {
        guard let actual = performedHolds(in: exercise, at: date), let prescribed = exercise.timedHolds else {
            return nil
        }
        var result = SetPerformance(asPrescribed: exercise)
        result.segments = (firstSideHolds ?? actual).map(ExerciseSegment.seconds)
        if let firstSideHolds, firstSideHolds != actual {
            result.secondSideSegments = actual.map(ExerciseSegment.seconds)
        }
        result.isPartial = actual != prescribed || (firstSideHolds != nil && firstSideHolds != prescribed)
        return result
    }

    private func performedHolds(in exercise: ExercisePrescription, at date: Date) -> [Int]? {
        guard let holds = exercise.timedHolds, holdNumber <= holds.count else { return nil }
        let target = holds[holdNumber - 1]
        let remaining = remainingExerciseTime(at: date)
        let elapsed = max(0, TimeInterval(target) - remaining).rounded(.down)
        let current = exerciseEnd == nil && pausedSeconds == nil ? 0 : (Int(exactly: elapsed) ?? target)
        return (completedHolds ?? []) + [current] + Array(repeating: 0, count: holds.count - holdNumber)
    }
}
