import Foundation
import SwiftData
import TrainingDomain

public struct ManualRoutine: Identifiable {
    public let id: UUID
    public let gymID: UUID
    public let revision: Int
    public var plan: RoutinePlan

    public init(gymID: UUID) {
        self.id = UUID()
        self.gymID = gymID
        self.revision = 0
        self.plan = RoutinePlan(name: "", days: [])
    }

    fileprivate init(_ record: TrainingSchemaV1.Routine) throws {
        self.id = record.id
        self.gymID = record.gymID
        self.revision = record.revision
        self.plan = try record.plan
    }
}

public enum RoutineEditorError: Error {
    case incompletePlan, changedRoutine
}

extension CoordinatedModelStore {
    public func editableRoutines(in gymID: UUID) throws -> [ManualRoutine] {
        try withContext { context in
            let query = FetchDescriptor<TrainingSchemaV1.Routine>(
                predicate: #Predicate { $0.gymID == gymID && !$0.isArchived })
            return try context.fetch(query).map(ManualRoutine.init).sorted {
                $0.plan.name.localizedStandardCompare($1.plan.name) == .orderedAscending
            }
        }
    }

    public func saveRoutine(_ draft: ManualRoutine) throws {
        let plan = draft.plan
        try validateForEditing(plan)

        try withContext { context in
            let id = draft.id
            let query = FetchDescriptor<TrainingSchemaV1.Routine>(predicate: #Predicate { $0.id == id })
            if let record = try context.fetch(query).first {
                guard record.gymID == draft.gymID, !record.isArchived, record.revision == draft.revision else {
                    throw RoutineEditorError.changedRoutine
                }
                try record.replacePlan(plan)
            } else {
                guard draft.revision == 0 else { throw RoutineEditorError.changedRoutine }
                let gymID = draft.gymID
                let gym = FetchDescriptor<TrainingSchemaV1.Gym>(predicate: #Predicate { $0.id == gymID })
                guard try context.fetchCount(gym) == 1 else { throw GymProfileError.missingGym }
                context.insert(try TrainingSchemaV1.Routine(id: id, gymID: gymID, plan: plan))
            }
            try context.save()
        }
    }
}

private func validateForEditing(_ plan: RoutinePlan) throws {
    func hasName(_ name: String) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    func validRest(_ duration: TimeInterval) -> Bool { duration.isFinite && duration >= 0 }

    guard hasName(plan.name), !plan.days.isEmpty, plan.defaultSets > 0,
        validRest(plan.restBetweenSets), validRest(plan.restBetweenExercises)
    else { throw RoutineEditorError.incompletePlan }

    for day in plan.days {
        guard hasName(day.name), !day.exercises.isEmpty else { throw RoutineEditorError.incompletePlan }
        for exercise in day.exercises {
            guard hasName(exercise.name), plan.setCount(for: exercise) > 0, !exercise.segments.isEmpty,
                exercise.restBetweenSets.map(validRest) != false, exercise.restAfterExercise.map(validRest) != false
            else { throw RoutineEditorError.incompletePlan }
            for segment in exercise.segments {
                switch segment {
                case .seconds(let value), .repetitions(let value):
                    guard value > 0 else { throw RoutineEditorError.incompletePlan }
                }
            }
        }
    }
}
