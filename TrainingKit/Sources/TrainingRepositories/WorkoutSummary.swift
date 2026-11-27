import Foundation
import SwiftData
import TrainingDomain

public struct WorkoutSummary: Identifiable, Sendable {
    public struct RecordedSet: Identifiable, Sendable {
        public let id: UUID
        public let performedAt: Date
        public let number: Int
        public let performance: SetPerformance
    }

    public struct Exercise: Identifiable, Sendable {
        public var id: UUID { prescription.id }
        public let prescription: ExercisePrescription
        public let sets: [RecordedSet]
        public let effort: Effort?
        public let skipped: Bool
        public var unperformed: Int { max(0, (prescription.sets ?? 0) - sets.count) }
    }

    public let id: UUID
    public let snapshot: SessionPrescription
    public let startedAt: Date
    public var duration: TimeInterval { finishedAt.timeIntervalSince(startedAt) }
    public var name: String { snapshot.day.name }
    public let finishedAt: Date
    public let partial: Bool
    public let exercises: [Exercise]

    init(session: TrainingSchemaV1.Session, context: ModelContext) throws {
        let sessionID = session.id
        let sets = try context.fetch(
            FetchDescriptor<TrainingSchemaV1.PerformedSet>(
                predicate: #Predicate { $0.sessionID == sessionID }, sortBy: [SortDescriptor(\.number)]))
        let ratings = try context.fetch(
            FetchDescriptor<TrainingSchemaV1.Rating>(
                predicate: #Predicate { $0.sessionID == sessionID }))
        try self.init(session: session, sets: sets, ratings: ratings)
    }

    init(session: TrainingSchemaV1.Session, sets: [TrainingSchemaV1.PerformedSet], ratings: [TrainingSchemaV1.Rating])
        throws
    {
        guard let finished = session.finishedAt else { throw SessionCommandError.sessionNotFound }
        id = session.id
        finishedAt = finished
        startedAt = session.startedAt
        partial = session.isPartial
        snapshot = try session.prescription
        let grouped = Dictionary(grouping: sets, by: \.exerciseID)
        exercises = try snapshot.day.exercises.map { exercise in
            try Exercise(
                prescription: exercise,
                sets: grouped[exercise.id, default: []].map {
                    RecordedSet(
                        id: $0.id, performedAt: $0.performedAt, number: $0.number, performance: try $0.performance)
                }, effort: ratings.first { $0.exerciseID == exercise.id }?.effort,
                skipped: session.skippedExerciseIDs.contains(exercise.id))
        }
    }
}

extension CoordinatedModelStore {
    public func pendingWorkoutSummary() throws -> WorkoutSummary? {
        try withContext { context in
            var query = FetchDescriptor<TrainingSchemaV1.Session>(
                predicate: #Predicate { $0.finishedAt != nil }, sortBy: [SortDescriptor(\.finishedAt, order: .reverse)])
            query.fetchLimit = 1
            guard let session = try context.fetch(query).first, try session.prescription.summaryPending == true else {
                return nil
            }
            return try WorkoutSummary(session: session, context: context)
        }
    }

    public func acknowledgeWorkoutSummary(id: UUID) throws {
        try withContext { context in
            let writer = SessionWriter(context: context, sessionID: id)
            guard let session = try writer.session() else { throw SessionCommandError.sessionNotFound }
            var plan = try session.prescription
            guard plan.summaryPending == true else { return }
            plan.summaryPending = nil
            try session.updatePrescription(plan)
            try context.save()
        }
    }

    public func workoutSummary(id: UUID) throws -> WorkoutSummary {
        try withContext { context in
            let query = FetchDescriptor<TrainingSchemaV1.Session>(predicate: #Predicate { $0.id == id })
            guard let session = try context.fetch(query).first else { throw SessionCommandError.sessionNotFound }
            return try WorkoutSummary(session: session, context: context)
        }
    }
}
