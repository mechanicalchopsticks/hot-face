import Foundation
import SwiftData
import TrainingDomain

public struct ExerciseProgress: Identifiable, Sendable {
    public struct Context: Hashable, Sendable {
        public let gymID: UUID
        public let equipmentID: UUID?
        public let name: String
        public let variant: String?
        public let station: String?
        public let bandColor: ResistanceBandColor?
        public let unit: ExerciseLoad.Unit?
        public let representation: ExerciseLoad.Representation?
        public let implementCount: Int?
        public let perSide: Bool
    }

    public let id: Context
    public let gymName: String
    public let equipment: EquipmentDescription?
    public fileprivate(set) var sets: [WorkoutSummary.RecordedSet]
    public var heaviestLoad: ExerciseLoad? {
        sets.compactMap(\.performance.load).max { $0.amount < $1.amount }
    }
    public var mostRepetitions: Int? {
        sets.compactMap { set in
            guard set.performance.segments.count == 1, case .repetitions(let count) = set.performance.segments[0]
            else { return nil }
            return count
        }.max()
    }
    public var longestHold: Int? {
        sets.flatMap { set in
            (set.performance.segments + (set.performance.secondSideSegments ?? [])).compactMap { segment -> Int? in
                guard case .seconds(let seconds) = segment else { return nil }
                return seconds
            }
        }.max()
    }
}

public struct WorkoutHistory: Sendable {
    public let sessions: [WorkoutSummary]

    public var progress: [ExerciseProgress] {
        var groups: [ExerciseProgress.Context: ExerciseProgress] = [:]
        for session in sessions {
            let snapshot = session.snapshot
            for exercise in session.exercises {
                let prescription = exercise.prescription
                let equipment = snapshot.equipment.first { $0.id == prescription.equipmentID }
                for set in exercise.sets {
                    let load = set.performance.load
                    let key = ExerciseProgress.Context(
                        gymID: snapshot.gymID, equipmentID: prescription.equipmentID, name: prescription.name,
                        variant: prescription.variant, station: prescription.station ?? equipment?.station,
                        bandColor: prescription.bandColor, unit: load?.unit, representation: load?.representation,
                        implementCount: load?.implementCount, perSide: set.performance.perSide)
                    groups[
                        key,
                        default: ExerciseProgress(id: key, gymName: snapshot.gymName, equipment: equipment, sets: [])
                    ].sets.append(set)
                }
            }
        }
        return groups.values.map { value in
            var result = value
            result.sets.sort { ($0.performedAt, $0.id) > ($1.performedAt, $1.id) }
            return result
        }.sorted {
            ($0.id.name, $0.gymName, $0.sets[0].id) < ($1.id.name, $1.gymName, $1.sets[0].id)
        }
    }
}

extension CoordinatedModelStore {
    public func workoutHistory() throws -> WorkoutHistory {
        try withContext { try Self.workoutHistory(in: $0) }
    }

    static func workoutHistory(in context: ModelContext) throws -> WorkoutHistory {
        let sessions = try context.fetch(
            FetchDescriptor<TrainingSchemaV1.Session>(
                predicate: #Predicate { $0.finishedAt != nil },
                sortBy: [SortDescriptor(\.finishedAt, order: .reverse), SortDescriptor(\.id)]))
        let sets = try Dictionary(
            grouping: context.fetch(
                FetchDescriptor<TrainingSchemaV1.PerformedSet>(
                    sortBy: [SortDescriptor(\.number)])), by: \.sessionID)
        let ratings = try Dictionary(
            grouping: context.fetch(FetchDescriptor<TrainingSchemaV1.Rating>()), by: \.sessionID)
        return try WorkoutHistory(
            sessions: sessions.map { session in
                try WorkoutSummary(
                    session: session, sets: sets[session.id, default: []], ratings: ratings[session.id, default: []])
            })
    }
}
