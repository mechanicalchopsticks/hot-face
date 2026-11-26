import Foundation
import SwiftData
import TrainingDomain

public enum WeightSuggestionError: Error {
    case suggestionChanged, invalidAdjustment
}

extension CoordinatedModelStore {
    public func suggestedWeightIncrease(routineID: UUID, exerciseID: UUID, mode: WeightProgressionMode = .conservative)
        throws -> WeightSuggestion?
    {
        guard
            case .suggested(let suggestion) = try progressionAdvice(
                routineID: routineID, exerciseID: exerciseID, mode: mode),
            suggestion.reason != .lowerLoad, suggestion.reason != .fewerRepetitions
        else { return nil }
        return suggestion
    }

    public func progressionAdvice(routineID: UUID, exerciseID: UUID, mode: WeightProgressionMode = .conservative) throws
        -> ProgressionAdvice?
    {
        try progressionOffer(routineID: routineID, exerciseID: exerciseID, mode: mode)?.advice
    }

    public func progressionOffer(routineID: UUID, exerciseID: UUID, mode: WeightProgressionMode = .conservative) throws
        -> (advice: ProgressionAdvice, loads: [ExerciseLoad])?
    {
        try progressionOffer(routineID: routineID, exerciseID: exerciseID, session: nil, mode: mode)
    }

    public func progressionOffer(
        routineID: UUID, exerciseID: UUID, sessionID: UUID, clock: any WorkoutClock,
        mode: WeightProgressionMode = .conservative
    ) throws
        -> (advice: ProgressionAdvice, loads: [ExerciseLoad])?
    {
        try progressionOffer(routineID: routineID, exerciseID: exerciseID, session: (sessionID, clock), mode: mode)
    }

    private func progressionOffer(
        routineID: UUID, exerciseID: UUID, session: (id: UUID, clock: any WorkoutClock)?, mode: WeightProgressionMode
    )
        throws
        -> (advice: ProgressionAdvice, loads: [ExerciseLoad])?
    {
        try withContext { context in
            guard let routine = try routineRecord(id: routineID, context: context), !routine.isArchived,
                let day = try routine.plan.days.first(where: { $0.exercises.contains { $0.id == exerciseID } }),
                let usual = day.exercises.first(where: { $0.id == exerciseID })
            else { return nil }
            if let session,
                try eligibleSession(
                    session.id, for: usual, routineID: routineID, dayID: day.id, at: session.clock.now,
                    in: context) == nil
            {
                return nil
            }
            let pending = try pendingAdvice(for: usual, gymID: routine.gymID, mode: mode, in: context)
            // Reading a pre-inventory gym can materialize its shared inventory.
            if context.hasChanges { try context.save() }
            guard let pending else { return nil }
            if case .suggested(let suggestion) = pending.advice,
                let equipment = pending.profile.equipment(withID: usual.equipmentID)
            {
                var loads = pending.profile.inventory.loadOptions(for: equipment, displayedLike: suggestion.load)
                if !loads.contains(suggestion.load) { loads.append(suggestion.load) }
                return (pending.advice, loads)
            }
            return (pending.advice, [])
        }
    }

    /// Accept the suggestion as shown, checking the current inventory and progression under the store lock.
    public func acceptWeightIncrease(
        _ suggestion: WeightSuggestion, routineID: UUID, exerciseID: UUID, clock: any WorkoutClock,
        mode: WeightProgressionMode = .conservative
    ) throws {
        try acceptProgressionSuggestion(
            suggestion, load: suggestion.load, repetitions: suggestion.repetitions,
            routineID: routineID, exerciseID: exerciseID, clock: clock, mode: mode)
    }

    public func acceptProgressionSuggestion(
        _ suggestion: WeightSuggestion, load: ExerciseLoad, repetitions: Int, routineID: UUID, exerciseID: UUID,
        sessionID: UUID? = nil, clock: any WorkoutClock, mode: WeightProgressionMode = .conservative
    ) throws {
        try withContext { context in
            guard let routine = try routineRecord(id: routineID, context: context), !routine.isArchived
            else { throw WeightSuggestionError.suggestionChanged }
            var plan = try routine.plan
            guard let day = plan.days.firstIndex(where: { $0.exercises.contains { $0.id == exerciseID } }),
                let index = plan.days[day].exercises.firstIndex(where: { $0.id == exerciseID })
            else { throw WeightSuggestionError.suggestionChanged }
            let previous = plan.days[day].exercises[index]
            guard let pending = try pendingAdvice(for: previous, gymID: routine.gymID, mode: mode, in: context),
                pending.advice == .suggested(suggestion)
            else { throw WeightSuggestionError.suggestionChanged }

            guard repetitions > 0 else { throw WeightSuggestionError.invalidAdjustment }
            let equipment = pending.profile.equipment(withID: previous.equipmentID)
            let finalWeight = try load.addedKilograms(equipment: equipment)
            if load != suggestion.load {
                guard let equipment, load.implementCount == suggestion.load.implementCount,
                    pending.profile.inventory.loadOptions(for: equipment, displayedLike: load).contains(load)
                else { throw WeightSuggestionError.invalidAdjustment }
            }
            var updated = previous
            updated.load = .confirmed(load)
            updated.segments = [.repetitions(repetitions)]
            let date = clock.now
            if let sessionID {
                guard
                    let (session, prescription, position) = try eligibleSession(
                        sessionID, for: previous, routineID: routineID, dayID: plan.days[day].id, at: date, in: context)
                else { throw WeightSuggestionError.suggestionChanged }
                var snapshot = prescription
                snapshot.day.exercises[position].load = updated.load
                snapshot.day.exercises[position].segments = updated.segments
                // Acceptance replaces the temporary load and reps. Only a different set count can still be reused.
                if snapshot.day.exercises[position].sets == plan.setCount(for: updated) {
                    snapshot.temporaryExerciseIDs?.remove(exerciseID)
                }
                try session.updatePrescription(snapshot)
            }
            plan.days[day].exercises[index] = updated
            try routine.saveUsualPlan(plan, in: context)
            pending.progression.balance = 0
            let sameWeight = try suggestion.load.addedKilograms(equipment: equipment) == finalWeight
            pending.progression.returnRepetitions =
                sameWeight && repetitions == suggestion.repetitions
                ? suggestion.returnRepetitionsOnAcceptance : nil
            context.insert(
                try TrainingSchemaV1.PrescriptionChange(
                    routineID: routineID, date: date, origin: "suggestion.\(suggestion.reason.rawValue)",
                    previous: previous, updated: updated))
            try context.save()
        }
    }
}

private func eligibleSession(
    _ sessionID: UUID, for usual: ExercisePrescription, routineID: UUID, dayID: UUID, at date: Date,
    in context: ModelContext
) throws -> (TrainingSchemaV1.Session, SessionPrescription, Int)? {
    let writer = SessionWriter(context: context, sessionID: sessionID)
    guard let session = try writer.session(), session.finishedAt == nil else { return nil }
    let workout = try writer.workout(session, at: date)
    let snapshot = workout.prescription
    guard snapshot.routineID == routineID, snapshot.day.id == dayID,
        workout.activeRest(at: date) == nil, workout.timer == nil,
        let next = workout.nextSet, next.exercise.id == usual.id, next.number == 1,
        next.exercise.equipmentID == usual.equipmentID,
        let position = snapshot.day.exercises.firstIndex(where: { $0.id == usual.id })
    else { return nil }
    return (session, snapshot, position)
}

private func pendingAdvice(
    for usual: ExercisePrescription, gymID: UUID, mode: WeightProgressionMode, in context: ModelContext
) throws
    -> (advice: ProgressionAdvice, progression: TrainingSchemaV1.Progression, profile: GymProfile)?
{
    let id = usual.id
    let query = FetchDescriptor<TrainingSchemaV1.Progression>(predicate: #Predicate { $0.exerciseID == id })
    guard let progression = try context.fetch(query).first, [-2, 2].contains(progression.balance) else { return nil }
    let profile = try gymProfile(withID: gymID, in: context)
    guard
        let suggestion = ProgressionAdvice.evaluate(
            for: usual, balance: progression.balance, equipment: profile.equipment(withID: usual.equipmentID),
            inventory: profile.inventory,
            returnRepetitions: progression.returnRepetitions, mode: mode)
    else { return nil }
    return (suggestion, progression, profile)
}
