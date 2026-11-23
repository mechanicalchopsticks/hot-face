import Foundation
import SwiftData
import TrainingDomain

public struct OpenWorkout: Identifiable, Sendable {
    public struct PendingSet: Sendable {
        public let exercise: ExercisePrescription
        public let equipment: EquipmentDescription?
        public let number: Int
        public let count: Int
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
            let betweenExercises = pending.exercise.id != last.exerciseID
            let seconds =
                betweenExercises
                ? exercise.restAfterExercise ?? prescription.restBetweenExercises
                : exercise.restBetweenSets ?? prescription.restBetweenSets
            let performance = try last.performance
            let original = prescription.restPrescription
            let segments = original?.setID == last.id ? original?.segments : exercise.segments
            let prescribedSegments = segments?.count == performance.segments.count ? segments : nil
            rest =
                seconds > 0
                ? Rest(
                    id: last.id, performance: performance,
                    prescribedSegments: prescribedSegments ?? performance.segments, completedSetNumber: last.number,
                    endsAt: last.performedAt.addingTimeInterval(seconds),
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

    public func openWorkout() throws -> OpenWorkout? {
        try withContext { context in
            var sessions = FetchDescriptor<TrainingSchemaV1.Session>(predicate: #Predicate { $0.finishedAt == nil })
            sessions.fetchLimit = 1
            guard let session = try context.fetch(sessions).first else { return nil }

            let id = session.id
            let performed = try context.fetch(
                FetchDescriptor<TrainingSchemaV1.PerformedSet>(
                    predicate: #Predicate { $0.sessionID == id },
                    sortBy: [SortDescriptor(\.performedAt, order: .reverse)]))
            return try OpenWorkout(session: session, performed: performed)
        }
    }
}
