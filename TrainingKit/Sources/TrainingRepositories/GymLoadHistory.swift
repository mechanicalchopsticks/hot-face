import Foundation
import SwiftData
import TrainingDomain

public struct HistoricalLoad: Sendable {
    public let load: ExerciseLoad
    public let performedAt: Date
    public let exercise: ExercisePrescription
    public let station: String?

    public func confirmed(amount: Decimal) -> PrescribedLoad {
        var edited = load
        edited.amount = amount
        return .confirmed(edited)
    }
}

public struct GymLoadHistory: Sendable {
    fileprivate var latest: [String: HistoricalLoad] = [:]

    public subscript(exerciseName: String) -> HistoricalLoad? {
        latest[Self.key(exerciseName)]
    }

    public func suggestion(for exercise: ExercisePrescription) -> HistoricalLoad? {
        exercise.load == .undefined ? self[exercise.name] : nil
    }

    fileprivate static func key(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

extension CoordinatedModelStore {
    public func loadHistory(in gymID: UUID) throws -> GymLoadHistory {
        try withContext { context in
            var history = GymLoadHistory()
            for session in try context.fetch(FetchDescriptor<TrainingSchemaV1.Session>()) {
                let snapshot = try session.prescription
                guard snapshot.gymID == gymID else { continue }
                let id = session.id
                let sets = FetchDescriptor<TrainingSchemaV1.PerformedSet>(
                    predicate: #Predicate { $0.sessionID == id },
                    sortBy: [SortDescriptor(\.performedAt, order: .reverse), SortDescriptor(\.number, order: .reverse)])
                for set in try context.fetch(sets) {
                    guard let exercise = snapshot.day.exercises.first(where: { $0.id == set.exerciseID }) else {
                        continue
                    }
                    let key = GymLoadHistory.key(exercise.name)
                    if let newer = history.latest[key], newer.performedAt >= set.performedAt { continue }
                    guard let load = try set.performance.load else { continue }
                    let station =
                        exercise.station ?? snapshot.equipment.first { $0.id == exercise.equipmentID }?.station
                    history.latest[key] = HistoricalLoad(
                        load: load, performedAt: set.performedAt, exercise: exercise, station: station)
                }
            }
            return history
        }
    }
}
