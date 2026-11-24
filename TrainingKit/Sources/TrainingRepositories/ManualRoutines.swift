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

    public func copy() -> ManualRoutine {
        var draft = ManualRoutine(gymID: gymID)
        draft.plan = plan.copiedForNewRoutine()
        return draft
    }

    fileprivate init(_ record: TrainingSchemaV1.Routine) throws {
        self.id = record.id
        self.gymID = record.gymID
        self.revision = record.revision
        self.plan = try record.plan
    }
}

public enum RoutineEditorError: Error, Equatable {
    case incompletePlan, changedRoutine
    case openSession(UUID)
}

extension CoordinatedModelStore {
    public func activeRoutine() throws -> ManualRoutine? {
        try withContext { context in
            guard let gymID = try selectedGymID(in: context) else { return nil }
            return try activeRoutineRecord(in: gymID, context: context).map(ManualRoutine.init)
        }
    }

    public func routine(id: UUID) throws -> ManualRoutine? {
        try withContext { context in
            try routineRecord(id: id, context: context).map(ManualRoutine.init)
        }
    }

    public func editableRoutines(in gymID: UUID) throws -> [ManualRoutine] {
        try routines(in: gymID, archived: false)
    }

    public func archivedRoutines(in gymID: UUID) throws -> [ManualRoutine] {
        try routines(in: gymID, archived: true)
    }

    private func routines(in gymID: UUID, archived: Bool) throws -> [ManualRoutine] {
        try withContext { context in
            let query = FetchDescriptor<TrainingSchemaV1.Routine>(
                predicate: #Predicate { $0.gymID == gymID && $0.isArchived == archived })
            return try context.fetch(query).map(ManualRoutine.init).sorted {
                $0.plan.name.localizedStandardCompare($1.plan.name) == .orderedAscending
            }
        }
    }

    public func saveRoutine(_ draft: ManualRoutine) throws {
        let plan = draft.plan
        try validateForEditing(plan)

        try withContext { context in
            guard try selectedGymID(in: context) == draft.gymID else { throw RoutineEditorError.changedRoutine }
            let id = draft.id
            let query = FetchDescriptor<TrainingSchemaV1.Routine>(predicate: #Predicate { $0.id == id })
            let existing = try context.fetch(query).first
            if let record = existing {
                guard record.gymID == draft.gymID, !record.isArchived, record.revision == draft.revision else {
                    throw RoutineEditorError.changedRoutine
                }
            } else if draft.revision != 0 {
                throw RoutineEditorError.changedRoutine
            }

            let others = try unarchivedRoutines(in: context).filter { $0.id != id }
            if existing == nil || !others.isEmpty { try requireClosedSession(in: context) }
            let previousPlan = try existing?.plan
            let previousIDs = Set((previousPlan?.days ?? []).flatMap(\.exercises).map(\.id))
            let addedIDs = plan.days.flatMap(\.exercises).map(\.id).filter { !previousIDs.contains($0) }
            if !addedIDs.isEmpty {
                let conflicts = FetchDescriptor<TrainingSchemaV1.Progression>(
                    predicate: #Predicate { addedIDs.contains($0.exerciseID) })
                guard try context.fetchCount(conflicts) == 0 else { throw RoutineEditorError.changedRoutine }
                for id in addedIDs { context.insert(TrainingSchemaV1.Progression(exerciseID: id)) }
            }
            if let existing {
                try existing.replacePlan(plan)
            } else {
                context.insert(try TrainingSchemaV1.Routine(id: id, gymID: draft.gymID, plan: plan))
            }
            for other in others { other.isArchived = true }
            try context.save()
        }
    }

    public func archiveRoutine(_ routine: ManualRoutine) throws {
        try withContext { context in
            let id = routine.id
            let query = FetchDescriptor<TrainingSchemaV1.Routine>(predicate: #Predicate { $0.id == id })
            guard let record = try context.fetch(query).first, record.revision == routine.revision,
                try selectedGymID(in: context) == routine.gymID
            else { throw RoutineEditorError.changedRoutine }
            guard !record.isArchived else { return }
            try requireClosedSession(in: context)
            record.isArchived = true
            try context.save()
        }
    }
}

func requireClosedSession(in context: ModelContext) throws {
    let query = FetchDescriptor<TrainingSchemaV1.Session>(predicate: #Predicate { $0.finishedAt == nil })
    if let session = try context.fetch(query).first { throw RoutineEditorError.openSession(session.id) }
}

func unarchivedRoutines(in context: ModelContext) throws -> [TrainingSchemaV1.Routine] {
    try context.fetch(FetchDescriptor<TrainingSchemaV1.Routine>(predicate: #Predicate { !$0.isArchived }))
}

func routineRecord(id: UUID, context: ModelContext) throws -> TrainingSchemaV1.Routine? {
    try context.fetch(FetchDescriptor<TrainingSchemaV1.Routine>(predicate: #Predicate { $0.id == id })).first
}

func activeRoutineRecord(in gymID: UUID, context: ModelContext) throws -> TrainingSchemaV1.Routine? {
    // Older editors allowed multiple saved routines. Let the user choose which to activate.
    var query = FetchDescriptor<TrainingSchemaV1.Routine>(predicate: #Predicate { $0.gymID == gymID && !$0.isArchived })
    query.fetchLimit = 2
    let candidates = try context.fetch(query)
    return candidates.count == 1 ? candidates.first : nil
}

func validateForEditing(_ plan: RoutinePlan) throws {
    func hasName(_ name: String) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    func validRest(_ duration: TimeInterval) -> Bool { duration.isFinite && duration >= 0 }

    guard hasName(plan.name), !plan.days.isEmpty, plan.defaultSets > 0,
        validRest(plan.restBetweenSets), validRest(plan.restBetweenExercises)
    else { throw RoutineEditorError.incompletePlan }

    for day in plan.days {
        try day.validateSupersets(defaultSets: plan.defaultSets)
        guard hasName(day.name), !day.exercises.isEmpty else { throw RoutineEditorError.incompletePlan }
        for settings in day.supersetRests.values {
            guard settings.restBetweenRounds.map(validRest) != false,
                settings.restAfterSuperset.map(validRest) != false
            else { throw RoutineEditorError.incompletePlan }
        }
        for exercise in day.exercises {
            guard hasName(exercise.name), plan.setCount(for: exercise) > 0, !exercise.segments.isEmpty,
                (exercise.pauseBetweenHolds ?? 0) >= 0, exercise.restBetweenSets.map(validRest) != false,
                exercise.restAfterExercise.map(validRest) != false
            else { throw RoutineEditorError.incompletePlan }
            for segment in exercise.segments {
                switch segment {
                case .seconds(let value), .repetitions(let value):
                    guard value > 0 else { throw RoutineEditorError.incompletePlan }
                case .toFailure:
                    break
                }
            }
        }
    }
}
