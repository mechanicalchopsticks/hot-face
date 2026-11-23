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
        case .logSet(let id, let number, let performance):
            _ = try perform(.completeSet(exerciseID: id, number: number, performance: performance), at: date)
            try finishIfResolved(openSession(), at: date)
        case .skipAndAdvance(let id):
            _ = try perform(.skip(exerciseID: id), at: date)
            try finishIfResolved(openSession(), at: date)
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
        case .moveExercise(let id, let toFront):
            let session = try openSession()
            var plan = try session.prescription
            guard let index = plan.day.exercises.firstIndex(where: { $0.id == id }) else {
                throw SessionCommandError.unknownExercise
            }
            let exercise = plan.day.exercises.remove(at: index)
            plan.day.exercises.insert(exercise, at: toFront ? 0 : plan.day.exercises.endIndex)
            try session.updatePrescription(plan)
        case .insertExercise(let sourceID, let replacing, let usual):
            try insertExercise(sourceID, replacing: replacing, usual: usual, in: openSession(), at: date)
        case .adjust(let id, let sets, let segments, let load, let saveAsUsual):
            let session = try openSession()
            var snapshot = try session.prescription
            guard let index = snapshot.day.exercises.firstIndex(where: { $0.id == id }) else {
                throw SessionCommandError.unknownExercise
            }
            let performed = FetchDescriptor<V1.PerformedSet>(
                predicate: #Predicate { $0.sessionID == sessionID && $0.exerciseID == id })
            guard sets > 0, try context.fetch(performed).allSatisfy({ $0.number <= sets }) else {
                throw SessionCommandError.invalidSetNumber
            }
            func adjust(_ exercise: inout ExercisePrescription) {
                exercise.sets = sets
                exercise.segments = segments
                exercise.load = load
            }
            // The correction form still describes the performed set when the next set changes during rest.
            if segments != snapshot.day.exercises[index].segments,
                let last = try context.fetch(performed).max(by: { $0.performedAt < $1.performedAt }),
                snapshot.restPrescription?.setID != last.id
            {
                snapshot.restPrescription = .init(setID: last.id, segments: snapshot.day.exercises[index].segments)
            }
            adjust(&snapshot.day.exercises[index])
            try validateForEditing(RoutinePlan(name: snapshot.routineName, days: [snapshot.day]))
            var temporaryIDs = snapshot.temporaryExerciseIDs ?? []
            if saveAsUsual {
                guard let routine = try activeRoutineRecord(in: snapshot.gymID, context: context),
                    routine.id == snapshot.routineID
                else { throw SessionCommandError.missingRoutine }
                var plan = try routine.plan
                guard let d = plan.days.firstIndex(where: { $0.id == snapshot.day.id }),
                    let e = plan.days[d].exercises.firstIndex(where: { $0.id == id })
                else { throw SessionCommandError.unknownExercise }
                let previous = plan.days[d].exercises[e]
                adjust(&plan.days[d].exercises[e])
                if previous != plan.days[d].exercises[e] {
                    try routine.replacePlan(plan)
                    context.insert(
                        try V1.PrescriptionChange(
                            routineID: routine.id, date: date, origin: "workout", previous: previous,
                            updated: plan.days[d].exercises[e]))
                    let query = FetchDescriptor<V1.Progression>(predicate: #Predicate { $0.exerciseID == id })
                    if let progression = try context.fetch(query).first {
                        progression.balance = 0
                        progression.returnRepetitions = nil
                    }
                }
                temporaryIDs.remove(id)
            } else {
                temporaryIDs.insert(id)
            }
            snapshot.temporaryExerciseIDs = temporaryIDs
            try session.updatePrescription(snapshot)
        case .correctSet(let id, let performance):
            _ = try openSession()
            let query = FetchDescriptor<V1.PerformedSet>(
                predicate: #Predicate { $0.sessionID == sessionID && $0.id == id })
            guard let set = try context.fetch(query).first else { throw SessionCommandError.invalidSetNumber }
            try set.correct(to: performance)
        case .rate(let id, let effort), .rateFinished(let id, let effort):
            guard let session = existing else { throw SessionCommandError.sessionNotFound }
            if case .rateFinished = action {
                guard session.finishedAt != nil else { throw SessionCommandError.sessionAlreadyOpen }
            } else {
                _ = try openSession()
            }
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

    private func finishIfResolved(_ session: V1.Session, at date: Date) throws {
        let sets = try context.fetch(
            FetchDescriptor<V1.PerformedSet>(predicate: #Predicate { $0.sessionID == sessionID }))
        let state = try OpenWorkout(session: session, performed: sets)
        if state.nextSet == nil { _ = try perform(.finish, at: date) }
    }

    private func insertExercise(_ sourceID: UUID, replacing: UUID?, usual: Bool, in session: V1.Session, at date: Date)
        throws
    {
        var snapshot = try session.prescription
        guard let routine = try activeRoutineRecord(in: snapshot.gymID, context: context),
            routine.id == snapshot.routineID
        else { throw SessionCommandError.missingRoutine }
        var plan = try routine.plan
        guard let source = plan.days.flatMap(\.exercises).first(where: { $0.id == sourceID }),
            let d = plan.days.firstIndex(where: { $0.id == snapshot.day.id })
        else { throw SessionCommandError.unknownExercise }
        var newExercise = source.copiedForWorkout()
        newExercise.sets = plan.setCount(for: source)
        if let equipmentID = newExercise.equipmentID, !snapshot.equipment.contains(where: { $0.id == equipmentID }) {
            let gymID = snapshot.gymID
            let gyms = FetchDescriptor<V1.Gym>(predicate: #Predicate { $0.id == gymID })
            guard let gym = try context.fetch(gyms).first,
                let equipment = try (gym.equipment + EquipmentDescription.genericOptions(in: gymID)).first(where: {
                    $0.id == equipmentID
                })
            else { throw SessionCommandError.missingEquipment }
            snapshot.equipment.append(equipment)
        }
        if let replacing {
            guard let index = snapshot.day.exercises.firstIndex(where: { $0.id == replacing }) else {
                throw SessionCommandError.unknownExercise
            }
            let records = FetchDescriptor<V1.PerformedSet>(
                predicate: #Predicate { $0.sessionID == sessionID && $0.exerciseID == replacing })
            if try context.fetchCount(records) == 0 {
                snapshot.day.exercises.remove(at: index)
            } else {
                session.skippedExerciseIDs.append(replacing)
            }
            snapshot.day.exercises.insert(newExercise, at: index)
        } else {
            snapshot.day.exercises.append(newExercise)
        }
        if usual {
            if let replacing {
                guard let index = plan.days[d].exercises.firstIndex(where: { $0.id == replacing }) else {
                    throw SessionCommandError.unknownExercise
                }
                let old = plan.days[d].exercises[index]
                plan.days[d].exercises[index] = newExercise
                context.insert(
                    try V1.PrescriptionChange(
                        routineID: routine.id, date: date, origin: "replacement", previous: old, updated: newExercise))
            } else {
                plan.days[d].exercises.append(newExercise)
            }
            plan.days[d].assignGroup(newExercise.group, to: newExercise.id)
            try routine.replacePlan(plan)
            context.insert(V1.Progression(exerciseID: newExercise.id))
        }
        try session.updatePrescription(snapshot)
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
