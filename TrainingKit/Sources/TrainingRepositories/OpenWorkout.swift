import Foundation
import SwiftData
import TrainingDomain

public struct WorkoutTimingCue: Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case holdStarted, lastHoldStarted, holdEnded, sideCompleted, setCompleted, lastSetCompleted
    }

    public let date: Date
    public let kind: Kind
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
    public let prescription: SessionPrescription
    public let pendingExercises: [ExercisePrescription]
    public let nextSet: PendingSet?
    public let rest: Rest?
    public var timer: WorkoutTimeline? { prescription.timer }

    public func activeRest(at date: Date) -> Rest? {
        guard timer == nil, let rest, date < rest.endsAt else { return nil }
        return rest
    }

    /// Pending cues stop at the next transition that requires user input.
    public var timingCues: [WorkoutTimingCue] {
        guard let set = nextSet, var hold = timer, let durations = set.exercise.timedHolds else { return [] }
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
            guard let next else { break }
            hold = next
        }
        return cues
    }

    init(session: TrainingSchemaV1.Session, performed: [TrainingSchemaV1.PerformedSet]) throws {
        id = session.id
        let prescription = try session.prescription
        self.prescription = prescription

        let byExercise = Dictionary(grouping: performed, by: \.exerciseID)
        let skipped = Set(session.skippedExerciseIDs)
        var pending: PendingSet?
        var remaining: [ExercisePrescription] = []
        for exercise in prescription.day.exercises where !skipped.contains(exercise.id) {
            guard let count = exercise.sets, count > 0 else { throw CocoaError(.coderReadCorrupt) }
            let completed = Set(byExercise[exercise.id, default: []].map(\.number))
            if let number = (1...count).first(where: { !completed.contains($0) }) {
                let equipment = prescription.equipment.first { $0.id == exercise.equipmentID }
                remaining.append(exercise)
                if pending == nil {
                    pending = PendingSet(exercise: exercise, equipment: equipment, number: number, count: count)
                }
            }
        }
        pendingExercises = remaining
        nextSet = pending

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
            try writer.reconcileTimer(in: session, at: clock?.now ?? .now)
            guard session.finishedAt == nil else { return nil }
            return try writer.workout(session)
        }
    }
}
