import Foundation
import SwiftData
import TrainingDomain

public enum WeightSuggestionError: Error {
    case suggestionChanged, invalidAdjustment
}

extension CoordinatedModelStore {
    public func suggestedWeightIncrease(routineID: UUID, exerciseID: UUID) throws -> WeightSuggestion? {
        guard case .suggested(let suggestion) = try progressionAdvice(routineID: routineID, exerciseID: exerciseID),
            suggestion.reason != .lowerLoad, suggestion.reason != .fewerRepetitions
        else { return nil }
        return suggestion
    }

    public func progressionAdvice(routineID: UUID, exerciseID: UUID) throws -> ProgressionAdvice? {
        try progressionOffer(routineID: routineID, exerciseID: exerciseID)?.advice
    }

    public func progressionOffer(routineID: UUID, exerciseID: UUID) throws
        -> (advice: ProgressionAdvice, loads: [ExerciseLoad])?
    {
        try withContext { context in
            guard let routine = try routineRecord(id: routineID, context: context), !routine.isArchived,
                let usual = try routine.plan.days.flatMap(\.exercises).first(where: { $0.id == exerciseID })
            else { return nil }
            let pending = try pendingAdvice(for: usual, gymID: routine.gymID, in: context)
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
        _ suggestion: WeightSuggestion, routineID: UUID, exerciseID: UUID, clock: any WorkoutClock
    ) throws {
        try acceptProgressionSuggestion(
            suggestion, load: suggestion.load, repetitions: suggestion.repetitions,
            routineID: routineID, exerciseID: exerciseID, clock: clock)
    }

    public func acceptProgressionSuggestion(
        _ suggestion: WeightSuggestion, load: ExerciseLoad, repetitions: Int, routineID: UUID, exerciseID: UUID,
        sessionID: UUID? = nil, clock: any WorkoutClock
    ) throws {
        try withContext { context in
            guard let routine = try routineRecord(id: routineID, context: context), !routine.isArchived
            else { throw WeightSuggestionError.suggestionChanged }
            var plan = try routine.plan
            guard let day = plan.days.firstIndex(where: { $0.exercises.contains { $0.id == exerciseID } }),
                let index = plan.days[day].exercises.firstIndex(where: { $0.id == exerciseID })
            else { throw WeightSuggestionError.suggestionChanged }
            let previous = plan.days[day].exercises[index]
            guard let pending = try pendingAdvice(for: previous, gymID: routine.gymID, in: context),
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
            if let sessionID {
                let writer = SessionWriter(context: context, sessionID: sessionID)
                guard let session = try writer.session(), session.finishedAt == nil else {
                    throw WeightSuggestionError.suggestionChanged
                }
                let workout = try writer.workout(session, at: clock.now)
                var snapshot = workout.prescription
                guard snapshot.routineID == routineID, snapshot.day.id == plan.days[day].id,
                    workout.activeRest(at: clock.now) == nil, workout.timer == nil,
                    let next = workout.nextSet, next.exercise.id == exerciseID, next.number == 1,
                    next.exercise.equipmentID == previous.equipmentID,
                    let position = snapshot.day.exercises.firstIndex(where: { $0.id == exerciseID })
                else { throw WeightSuggestionError.suggestionChanged }
                snapshot.day.exercises[position].load = updated.load
                snapshot.day.exercises[position].segments = updated.segments
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
                    routineID: routineID, date: clock.now, origin: "suggestion.\(suggestion.reason.rawValue)",
                    previous: previous, updated: updated))
            try context.save()
        }
    }
}

private func pendingAdvice(for usual: ExercisePrescription, gymID: UUID, in context: ModelContext) throws
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
            returnRepetitions: progression.returnRepetitions)
    else { return nil }
    return (suggestion, progression, profile)
}
