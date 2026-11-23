import Foundation
import SwiftData
import TrainingDomain

public struct WorkoutSummary: Identifiable, Sendable {
    public struct RecordedSet: Identifiable, Sendable {
        public let id: UUID
        public let number: Int
        public let performance: SetPerformance
    }

    public struct Exercise: Identifiable, Sendable {
        public var id: UUID { prescription.id }
        public let prescription: ExercisePrescription
        public let sets: [RecordedSet]
        public let effort: Effort?
        public var unperformed: Int { max(0, (prescription.sets ?? 0) - sets.count) }
    }

    public let id: UUID
    public let name: String
    public let finishedAt: Date
    public let partial: Bool
    public let exercises: [Exercise]

    init(session: TrainingSchemaV1.Session, context: ModelContext) throws {
        let sessionID = session.id
        id = sessionID
        guard let finished = session.finishedAt else { throw SessionCommandError.sessionNotFound }
        finishedAt = finished
        partial = session.isPartial
        let day = try session.prescription.day
        name = day.name
        let sets = try context.fetch(
            FetchDescriptor<TrainingSchemaV1.PerformedSet>(
                predicate: #Predicate { $0.sessionID == sessionID }, sortBy: [SortDescriptor(\.number)]))
        let ratings = try context.fetch(
            FetchDescriptor<TrainingSchemaV1.Rating>(
                predicate: #Predicate { $0.sessionID == sessionID }))
        let grouped = Dictionary(grouping: sets, by: \.exerciseID)
        exercises = try day.exercises.map { exercise in
            try Exercise(
                prescription: exercise,
                sets: grouped[exercise.id, default: []].map {
                    RecordedSet(id: $0.id, number: $0.number, performance: try $0.performance)
                }, effort: ratings.first { $0.exerciseID == exercise.id }?.effort)
        }
    }
}

extension CoordinatedModelStore {
    public func workoutSummary(id: UUID) throws -> WorkoutSummary {
        try withContext { context in
            let query = FetchDescriptor<TrainingSchemaV1.Session>(predicate: #Predicate { $0.id == id })
            guard let session = try context.fetch(query).first else { throw SessionCommandError.sessionNotFound }
            return try WorkoutSummary(session: session, context: context)
        }
    }
}
