import Foundation
import SwiftData
import TrainingDomain

private typealias V1 = TrainingSchemaV1
private typealias Receipt = TrainingSchemaV2.CommandReceipt

public enum SessionCommandResult: Equatable, Sendable {
    case applied, alreadyApplied
}

public enum SessionCommandError: Error, Equatable {
    case conflictingIdentifier, sessionAlreadyOpen, sessionNotFound, sessionClosed
    case missingRoutine, missingGym, missingCycle, dayUnavailable
    case unknownExercise, skippedExercise, invalidSetNumber, conflictingSet
    case exerciseNotStarted, conflictingRating, missingEquipment
}

extension CoordinatedModelStore {
    /// The receipt and all effects share one save inside the app/extension write lock.
    public func apply(_ command: SessionCommand, clock: any WorkoutClock) throws -> SessionCommandResult {
        try withContext { context in
            let id = command.id
            let receipts = FetchDescriptor<Receipt>(predicate: #Predicate { $0.id == id })
            if let receipt = try context.fetch(receipts).first {
                guard try receipt.command == command else { throw SessionCommandError.conflictingIdentifier }
                return .alreadyApplied
            }

            let writer = SessionWriter(context: context, sessionID: command.sessionID)
            let result = try writer.perform(command.action, at: clock.now)
            context.insert(try Receipt(command))
            try context.save()
            return result
        }
    }
}

private struct SessionWriter {
    let context: ModelContext
    let sessionID: UUID

    func perform(_ action: SessionCommand.Action, at date: Date) throws -> SessionCommandResult {
        let sessions = FetchDescriptor<V1.Session>(predicate: #Predicate { $0.id == sessionID })
        let existing = try context.fetch(sessions).first
        func openSession() throws -> V1.Session {
            guard let existing else { throw SessionCommandError.sessionNotFound }
            guard existing.finishedAt == nil else { throw SessionCommandError.sessionClosed }
            return existing
        }

        switch action {
        case .start(let routineID, let gymID, let dayID, let cycleID):
            if let existing {
                let plan = try existing.prescription
                guard plan.routineID == routineID, plan.gymID == gymID, plan.day.id == dayID,
                    existing.cycleID == cycleID
                else { throw SessionCommandError.conflictingIdentifier }
                return .alreadyApplied
            }
            try start(routineID: routineID, gymID: gymID, dayID: dayID, cycleID: cycleID, at: date)
        case .completeSet(let id, let number, let performance):
            let session = try openSession()
            let target = try session.exercise(id)
            guard number > 0, number <= (try target.snapshotSetCount) else {
                throw SessionCommandError.invalidSetNumber
            }
            let sets = FetchDescriptor<V1.PerformedSet>(
                predicate: #Predicate {
                    $0.sessionID == sessionID && $0.exerciseID == id && $0.number == number
                })
            if let set = try context.fetch(sets).first {
                guard try set.performance == performance else { throw SessionCommandError.conflictingSet }
                return .alreadyApplied
            }
            guard !session.skippedExerciseIDs.contains(id) else { throw SessionCommandError.skippedExercise }
            context.insert(
                try V1.PerformedSet(
                    sessionID: sessionID, exerciseID: id, number: number,
                    performedAt: date, performance: performance))
        case .correctSet(let id, let performance):
            _ = try openSession()
            let query = FetchDescriptor<V1.PerformedSet>(
                predicate: #Predicate { $0.sessionID == sessionID && $0.id == id })
            guard let set = try context.fetch(query).first else { throw SessionCommandError.invalidSetNumber }
            try set.correct(to: performance)
        case .rate(let id, let effort):
            let session = try openSession()
            _ = try session.exercise(id)
            let ratings = FetchDescriptor<V1.Rating>(
                predicate: #Predicate { $0.sessionID == sessionID && $0.exerciseID == id })
            if let rating = try context.fetch(ratings).first {
                guard rating.effort == effort else { throw SessionCommandError.conflictingRating }
                return .alreadyApplied
            }
            let sets = FetchDescriptor<V1.PerformedSet>(
                predicate: #Predicate { $0.sessionID == sessionID && $0.exerciseID == id })
            guard try context.fetchCount(sets) > 0 else { throw SessionCommandError.exerciseNotStarted }
            context.insert(V1.Rating(sessionID: sessionID, exerciseID: id, effort: effort, date: date))
        case .skip(let id):
            let session = try openSession()
            _ = try session.exercise(id)
            guard !session.skippedExerciseIDs.contains(id) else { return .alreadyApplied }
            session.skippedExerciseIDs.append(id)
        case .finish:
            guard let session = existing else { throw SessionCommandError.sessionNotFound }
            guard session.finishedAt == nil else { return .alreadyApplied }
            let plan = try session.prescription
            let sets = try context.fetch(
                FetchDescriptor<V1.PerformedSet>(predicate: #Predicate { $0.sessionID == sessionID }))
            let byExercise = Dictionary(grouping: sets, by: \.exerciseID)
            let partial = try plan.day.exercises.contains {
                (byExercise[$0.id]?.count ?? 0) < (try $0.snapshotSetCount)
            }
            if let cycleID = session.cycleID {
                let cycle = try cycle(with: cycleID)
                let dayID = plan.day.id
                if !cycle.completedDayIDs.contains(dayID) { cycle.completedDayIDs.append(dayID) }
            }
            session.finish(at: date, partial: partial)
        }
        return .applied
    }

    private func start(routineID: UUID, gymID: UUID, dayID: UUID, cycleID: UUID?, at date: Date) throws {
        let open = FetchDescriptor<V1.Session>(predicate: #Predicate { $0.finishedAt == nil })
        guard try context.fetchCount(open) == 0 else { throw SessionCommandError.sessionAlreadyOpen }
        guard let routine = try activeRoutineRecord(in: gymID, context: context), routine.id == routineID else {
            throw SessionCommandError.missingRoutine
        }
        if let selected = try selectedGymID(in: context), selected != gymID { throw SessionCommandError.missingGym }
        let gyms = FetchDescriptor<V1.Gym>(predicate: #Predicate { $0.id == gymID })
        guard let gym = try context.fetch(gyms).first else { throw SessionCommandError.missingGym }
        let cycle = try cycleID.map(cycle(with:))
        if let cycle {
            guard cycle.orderedDayIDs.contains(dayID), !cycle.completedDayIDs.contains(dayID),
                !cycle.skippedDayIDs.contains(dayID)
            else { throw SessionCommandError.dayUnavailable }
        }
        let session = try V1.Session(
            id: sessionID, routine: routine, gym: gym, dayID: dayID, cycle: cycle, startedAt: date)
        let snapshot = try session.prescription
        let available = Set(snapshot.equipment.map(\.id))
        guard snapshot.day.exercises.compactMap(\.equipmentID).allSatisfy(available.contains) else {
            throw SessionCommandError.missingEquipment
        }
        context.insert(session)
    }

    private func cycle(with id: UUID) throws -> V1.Cycle {
        let cycles = FetchDescriptor<V1.Cycle>(predicate: #Predicate { $0.id == id })
        guard let cycle = try context.fetch(cycles).first else { throw SessionCommandError.missingCycle }
        return cycle
    }
}

extension ExercisePrescription {
    fileprivate var snapshotSetCount: Int {
        get throws {
            guard let sets else { throw CocoaError(.coderReadCorrupt) }
            return sets
        }
    }
}

extension V1.Session {
    fileprivate func exercise(_ id: UUID) throws -> ExercisePrescription {
        guard let exercise = try prescription.day.exercises.first(where: { $0.id == id }) else {
            throw SessionCommandError.unknownExercise
        }
        return exercise
    }
}
