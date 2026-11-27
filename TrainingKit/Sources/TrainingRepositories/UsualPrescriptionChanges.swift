import Foundation
import SwiftData
import TrainingDomain

extension TrainingSchemaV1.Routine {
    func saveUsualPlan(_ updated: RoutinePlan, at date: Date, origin: String, in context: ModelContext) throws {
        let previous = try plan
        let exercises = Dictionary(
            previous.days.flatMap(\.exercises).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let gymID = self.gymID
        let gyms = FetchDescriptor<TrainingSchemaV1.Gym>(predicate: #Predicate { $0.id == gymID })
        let equipment =
            try (context.fetch(gyms).first?.equipment ?? []) + EquipmentDescription.genericOptions(in: gymID)
        var changed: [UUID] = []
        for exercise in updated.days.flatMap(\.exercises) {
            guard let old = exercises[exercise.id] else { continue }
            let previousCount = previous.setCount(for: old)
            let updatedCount = updated.setCount(for: exercise)
            let prescriptionChanged =
                previousCount != updatedCount || old.segments != exercise.segments
                || old.perSide != exercise.perSide || !sameLoad(old, exercise, equipment: equipment)
            if prescriptionChanged { changed.append(exercise.id) }
            guard
                prescriptionChanged || old.name != exercise.name || old.variant != exercise.variant
                    || old.equipmentID != exercise.equipmentID || old.bandColor != exercise.bandColor
                    || old.load != exercise.load || old.station != exercise.station
            else { continue }
            var before = old
            var after = exercise
            // A later default-set edit must not change either side of this comparison.
            before.sets = previousCount
            after.sets = updatedCount
            context.insert(
                try TrainingSchemaV1.PrescriptionChange(
                    routineID: id, date: date, origin: origin, previous: before, updated: after))
        }
        if !changed.isEmpty {
            let query = FetchDescriptor<TrainingSchemaV1.Progression>(
                predicate: #Predicate { changed.contains($0.exerciseID) })
            for progression in try context.fetch(query) {
                progression.balance = 0
                progression.returnRepetitions = nil
            }
        }
        try replacePlan(updated)
    }
}

private func sameLoad(_ old: ExercisePrescription, _ new: ExercisePrescription, equipment: [EquipmentDescription])
    -> Bool
{
    if old.load.value == new.load.value && old.equipmentID == new.equipmentID { return true }
    guard let before = old.load.value, let after = new.load.value else { return old.load.value == new.load.value }
    guard let previous = try? before.addedKilograms(equipment: equipment.first { $0.id == old.equipmentID }),
        let current = try? after.addedKilograms(equipment: equipment.first { $0.id == new.equipmentID })
    else { return false }
    return previous == current
}
