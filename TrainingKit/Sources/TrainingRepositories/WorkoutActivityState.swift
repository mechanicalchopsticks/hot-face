import Foundation
import TrainingDomain

public struct WorkoutActivityState: Codable, Hashable, Sendable {
    public struct SetInfo: Codable, Hashable, Sendable {
        public let id: UUID
        public let name: String
        public let number: Int
        public let count: Int
        public let timed: Bool
        public let perSide: Bool

        init(_ set: OpenWorkout.PendingSet) {
            id = set.exercise.id
            // Keep the ActivityKit payload bounded even for long user-entered names.
            name = String(decoding: set.exercise.name.utf8.prefix(180), as: UTF8.self)
            number = set.number
            count = set.count
            timed = set.timedDuration != nil
            perSide = set.exercise.perSide
        }
    }

    public struct Frame: Codable, Hashable, Sendable {
        public let set: SetInfo?
        public let timer: WorkoutTimeline?
        public let restEnd: Date?
    }

    private let current: Frame
    private let afterExpiry: Frame?
    public let boundary: Date?
    public let timerStartRevision: Int?

    public init(_ workout: OpenWorkout) {
        timerStartRevision = workout.prescription.timerStartRevision
        let set = workout.nextSet
        current = Frame(
            set: set.map(SetInfo.init), timer: workout.timer,
            restEnd: workout.activeRest(at: workout.reconciledAt)?.endsAt)
        boundary = workout.nextBoundary
        if let set, let timer = workout.timer, let end = timer.exerciseEnd {
            if let next = timer.followingHold(in: set.exercise) {
                afterExpiry = Frame(set: SetInfo(set), timer: next, restEnd: nil)
            } else {
                afterExpiry = Frame(
                    set: workout.followingSet.map(SetInfo.init), timer: nil,
                    restEnd: workout.restAfterCurrentSet.flatMap { $0 > 0 ? end.addingTimeInterval($0) : nil })
            }
        } else {
            afterExpiry = nil
        }
    }

    public func frame(at date: Date) -> Frame? {
        if let end = current.timer?.exerciseEnd, end <= date {
            if let projectedEnd = afterExpiry?.timer?.exerciseEnd, projectedEnd <= date { return nil }
            return afterExpiry
        }
        return current
    }
}
