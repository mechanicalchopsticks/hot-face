import Foundation
import SwiftData
import TrainingDomain

public enum WeightSuggestionError: Error {
    case suggestionChanged
}

extension CoordinatedModelStore {
    public func suggestedWeightIncrease(routineID: UUID, exerciseID: UUID) throws -> WeightSuggestion? {
        try withContext { context in
            guard let routine = try routineRecord(id: routineID, context: context), !routine.isArchived,
                let usual = try routine.plan.days.flatMap(\.exercises).first(where: { $0.id == exerciseID })
            else { return nil }
            let pending = try weightIncrease(for: usual, gymID: routine.gymID, in: context)
            // Reading a pre-inventory gym can materialize its shared inventory.
            if context.hasChanges { try context.save() }
            return pending?.suggestion
        }
    }

    /// Accept the suggestion as shown, checking the current inventory and progression under the store lock.
    public func acceptWeightIncrease(
        _ suggestion: WeightSuggestion, routineID: UUID, exerciseID: UUID, clock: any WorkoutClock
    ) throws {
        try withContext { context in
            guard let routine = try routineRecord(id: routineID, context: context), !routine.isArchived
            else { throw WeightSuggestionError.suggestionChanged }
            var plan = try routine.plan
            guard let day = plan.days.firstIndex(where: { $0.exercises.contains { $0.id == exerciseID } }),
                let index = plan.days[day].exercises.firstIndex(where: { $0.id == exerciseID })
            else { throw WeightSuggestionError.suggestionChanged }
            let previous = plan.days[day].exercises[index]
            guard let pending = try weightIncrease(for: previous, gymID: routine.gymID, in: context),
                pending.suggestion == suggestion
            else { throw WeightSuggestionError.suggestionChanged }

            var updated = previous
            updated.load = .confirmed(suggestion.load)
            updated.segments = [.repetitions(suggestion.repetitions)]
            plan.days[day].exercises[index] = updated
            try routine.saveUsualPlan(plan, in: context)
            pending.progression.returnRepetitions = suggestion.returnRepetitionsOnAcceptance
            context.insert(
                try TrainingSchemaV1.PrescriptionChange(
                    routineID: routineID, date: clock.now, origin: "suggestion", previous: previous, updated: updated))
            try context.save()
        }
    }
}

private func weightIncrease(for usual: ExercisePrescription, gymID: UUID, in context: ModelContext) throws
    -> (suggestion: WeightSuggestion, progression: TrainingSchemaV1.Progression)?
{
    let id = usual.id
    let query = FetchDescriptor<TrainingSchemaV1.Progression>(predicate: #Predicate { $0.exerciseID == id })
    guard let progression = try context.fetch(query).first, progression.balance == 2 else { return nil }
    let profile = try gymProfile(withID: gymID, in: context)
    guard let equipment = profile.equipment(withID: usual.equipmentID),
        let suggestion = WeightSuggestion.increase(
            for: usual, balance: progression.balance, equipment: equipment, inventory: profile.inventory,
            returnRepetitions: progression.returnRepetitions)
    else { return nil }
    return (suggestion, progression)
}
