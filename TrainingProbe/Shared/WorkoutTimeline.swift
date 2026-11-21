import Foundation

enum WorkoutAction: String {
    case start, pause, resume, complete
}

enum WorkoutPhase: Equatable {
    case ready, preparation, exercise, paused, rest
}

struct WorkoutTimeline: Codable, Hashable {
    static let preparationDuration: TimeInterval = 3
    static let exerciseDuration: TimeInterval = 20
    static let restDuration: TimeInterval = 15

    var setNumber = 1
    var revision = 0
    var exerciseStart: Date?
    var exerciseEnd: Date?
    var restEnd: Date?
    var pausedSeconds: TimeInterval?

    func phase(at date: Date) -> WorkoutPhase {
        if pausedSeconds != nil { return .paused }
        if let exerciseStart, date < exerciseStart { return .preparation }
        if let exerciseEnd, date < exerciseEnd { return .exercise }
        if let restEnd, date < restEnd { return .rest }
        return .ready
    }

    func nextBoundary(after date: Date) -> Date? {
        [exerciseStart, exerciseEnd, restEnd].compactMap { $0 }.first { $0 > date }
    }

    func currentSet(at date: Date) -> Int {
        if let restEnd, date >= restEnd { return setNumber + 1 }
        return setNumber
    }

    func applying(_ action: WorkoutAction, at now: Date) -> Self? {
        let phase = phase(at: now)
        var next = Self(setNumber: currentSet(at: now), revision: revision + 1)
        switch (action, phase) {
        case (.start, .ready), (.resume, .paused):
            let start = now.addingTimeInterval(Self.preparationDuration)
            let end = start.addingTimeInterval(pausedSeconds ?? Self.exerciseDuration)
            next.exerciseStart = start
            next.exerciseEnd = end
            next.restEnd = end.addingTimeInterval(Self.restDuration)
        case (.pause, .preparation), (.pause, .exercise):
            guard let exerciseStart, let exerciseEnd else { return nil }
            next.pausedSeconds = exerciseEnd.timeIntervalSince(max(now, exerciseStart))
        case (.complete, .ready), (.complete, .preparation), (.complete, .exercise), (.complete, .paused):
            next.restEnd = now.addingTimeInterval(Self.restDuration)
        default:
            return nil
        }
        return next
    }
}
