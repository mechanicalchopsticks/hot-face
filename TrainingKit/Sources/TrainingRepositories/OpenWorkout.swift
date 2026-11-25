import Foundation
import SwiftData
import TrainingDomain

public struct WorkoutTimingCue: Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case holdStarted, lastHoldStarted, holdEnded, sideCompleted, setCompleted, lastSetCompleted, restCompleted
    }

    public let date: Date
    public let kind: Kind
}

/// Keeps an undelivered boundary cue when reconciliation publishes the next hold or set.
public struct ForegroundWorkoutCues {
    private var pending: [WorkoutTimingCue] = []

    public init() {}

    public var nextDate: Date? { pending.first?.date }

    public mutating func update(_ cues: [WorkoutTimingCue], at date: Date) {
        pending = pending.filter { $0.date <= date } + cues.filter { $0.date > date }
    }

    public mutating func takeDue(at date: Date) -> WorkoutTimingCue? {
        guard let first = pending.first, first.date <= date else { return nil }
        return pending.removeFirst()
    }
}

public struct OpenWorkout: Identifiable, Sendable {
    public struct PendingSet: Sendable {
        public let exercise: ExercisePrescription
        public let equipment: EquipmentDescription?
        public let number: Int
        public let count: Int

        /// Prescribed work for the entire set, excluding preparation and breaks.
        public var timedDuration: TimeInterval? {
            guard let holds = exercise.timedHolds else { return nil }
            let perSideDuration = holds.reduce(0.0) { $0 + TimeInterval($1) }
            return exercise.perSide ? 2 * perSideDuration : perSideDuration
        }
    }

    public struct Rest: Identifiable, Sendable {
        public let id: UUID
        public let performance: SetPerformance
        public let prescribedSegments: [ExerciseSegment]
        public let completedSetNumber: Int
        public let endsAt: Date
        public let betweenExercises: Bool
    }

    public let id: UUID
    public let reconciledAt: Date
    public let prescription: SessionPrescription
    public let pendingExercises: [ExercisePrescription]
    public let nextSet: PendingSet?
    /// The pending set after the current one completes, including superset round order.
    public let followingSet: PendingSet?
    public let rest: Rest?
    public var timer: WorkoutTimeline? { prescription.timer }
    public var nextSupersetRound: (number: Int, count: Int)? {
        guard let set = nextSet, let id = set.exercise.supersetID else { return nil }
        return (prescription.roundNumber(for: set.exercise, set: set.number), prescription.roundCount(in: id))
    }

    public func activeRest(at date: Date) -> Rest? {
        guard timer == nil, let rest, date < rest.endsAt else { return nil }
        return rest
    }

    public var nextBoundary: Date? {
        activeRest(at: reconciledAt)?.endsAt ?? timer?.nextBoundary(after: reconciledAt)
    }

    /// Pending cues stop at the next transition that requires user input.
    public var timingCues: [WorkoutTimingCue] {
        guard let set = nextSet, var hold = timer, let durations = set.exercise.timedHolds else {
            return rest.map { [.init(date: $0.endsAt, kind: .restCompleted)] } ?? []
        }
        var cues: [WorkoutTimingCue] = []
        while let start = hold.exerciseStart, let end = hold.exerciseEnd {
            let lastHold = hold.holdNumber == durations.count
            cues.append(.init(date: start, kind: lastHold && durations.count > 1 ? .lastHoldStarted : .holdStarted))
            let kind: WorkoutTimingCue.Kind
            if !lastHold {
                kind = .holdEnded
            } else if set.exercise.perSide && hold.sideNumber == 1 {
                kind = .sideCompleted
            } else {
                kind = set.number == set.count ? .lastSetCompleted : .setCompleted
            }
            let next = hold.followingHold(in: set.exercise)
            // Back-to-back holds share a boundary and sound the next hold's start cue once.
            if next?.exerciseStart != end { cues.append(.init(date: end, kind: kind)) }
            guard let next else {
                if let duration = restAfterCurrentSet, duration > 0 {
                    cues.append(.init(date: end.addingTimeInterval(duration), kind: .restCompleted))
                }
                break
            }
            hold = next
        }
        return cues
    }

    public var restAfterCurrentSet: TimeInterval? {
        guard let set = nextSet, let followingSet else { return nil }
        return prescription.restDuration(
            after: set.exercise, completedSet: set.number, before: followingSet.exercise, nextSet: followingSet.number)
    }

    init(session: TrainingSchemaV1.Session, performed: [TrainingSchemaV1.PerformedSet], at date: Date) throws {
        reconciledAt = date
        id = session.id
        let prescription = try session.prescription
        self.prescription = prescription

        let byExercise = Dictionary(grouping: performed, by: \.exerciseID)
        let skipped = Set(session.skippedExerciseIDs)
        var candidates: [(set: PendingSet, block: Int, round: Int, index: Int)] = []
        var remaining: [ExercisePrescription] = []
        var firstMemberIndex: [UUID: Int] = [:]
        for (index, exercise) in prescription.day.exercises.enumerated() {
            let block =
                exercise.supersetID.map { id in
                    if let first = firstMemberIndex[id] { return first }
                    firstMemberIndex[id] = index
                    return index
                } ?? index
            guard !skipped.contains(exercise.id) else { continue }
            guard let count = exercise.sets, count > 0 else { throw CocoaError(.coderReadCorrupt) }
            let completed = Set(byExercise[exercise.id, default: []].map(\.number))
            let numbers = (1...count).lazy.filter { !completed.contains($0) }.prefix(2)
            guard !numbers.isEmpty else { continue }
            remaining.append(exercise)
            let equipment = prescription.equipment.first { $0.id == exercise.equipmentID }
            for number in numbers {
                let set = PendingSet(exercise: exercise, equipment: equipment, number: number, count: count)
                candidates.append((set, block, prescription.roundNumber(for: exercise, set: number), index))
            }
        }
        candidates.sort {
            ($0.block, $0.round, $0.index, $0.set.number) < ($1.block, $1.round, $1.index, $1.set.number)
        }
        pendingExercises = remaining
        let pending = candidates.first?.set
        nextSet = pending
        followingSet = candidates.dropFirst().first?.set

        // The set's saved timestamp is the start of rest, including when a completion is retried.
        if let pending, let last = performed.first,
            let exercise = prescription.day.exercises.first(where: { $0.id == last.exerciseID })
        {
            let sameSuperset = exercise.supersetID != nil && exercise.supersetID == pending.exercise.supersetID
            let betweenExercises = !sameSuperset && pending.exercise.id != last.exerciseID
            let seconds = prescription.restDuration(
                after: exercise, completedSet: last.number, before: pending.exercise, nextSet: pending.number)
            let override = prescription.restOverride
            let deadline = override?.setID == last.id ? override?.endsAt : nil
            let performance = try last.performance
            let original = prescription.restPrescription
            let segments = original?.setID == last.id ? original?.segments : exercise.segments
            let prescribedSegments = segments?.count == performance.segments.count ? segments : nil
            rest =
                seconds > 0
                ? Rest(
                    id: last.id, performance: performance,
                    prescribedSegments: prescribedSegments ?? performance.segments, completedSetNumber: last.number,
                    endsAt: deadline ?? last.performedAt.addingTimeInterval(seconds),
                    betweenExercises: betweenExercises)
                : nil
        } else {
            rest = nil
        }
    }
}

extension CoordinatedModelStore {
    public func previousAdjustment(for exerciseID: UUID, in routineID: UUID) throws -> ExercisePrescription? {
        try withContext { context in
            let sessions = FetchDescriptor<TrainingSchemaV1.Session>(
                predicate: #Predicate { $0.finishedAt != nil }, sortBy: [SortDescriptor(\.finishedAt, order: .reverse)])
            for session in try context.fetch(sessions) {
                let plan = try session.prescription
                if plan.routineID == routineID, plan.temporaryExerciseIDs?.contains(exerciseID) == true,
                    let exercise = plan.day.exercises.first(where: { $0.id == exerciseID })
                {
                    return exercise
                }
            }
            return nil
        }
    }

    public func openWorkout(clock: (any WorkoutClock)? = nil) throws -> OpenWorkout? {
        try withContext { context in
            var sessions = FetchDescriptor<TrainingSchemaV1.Session>(predicate: #Predicate { $0.finishedAt == nil })
            sessions.fetchLimit = 1
            guard let session = try context.fetch(sessions).first else { return nil }
            let writer = SessionWriter(context: context, sessionID: session.id)
            let date = clock?.now ?? .now
            try writer.reconcileTimer(in: session, at: date)
            guard session.finishedAt == nil else { return nil }
            return try writer.workout(session, at: date)
        }
    }
}
