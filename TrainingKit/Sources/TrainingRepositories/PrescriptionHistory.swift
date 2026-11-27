import Foundation
import SwiftData
import TrainingDomain

public struct PrescriptionHistoryEntry: Identifiable, Sendable {
    public enum Equipment: Equatable, Sendable {
        case generic(EquipmentDescription.Kind)
        case named(String)
        case unavailable(UUID)
    }

    public let previousEquipment: Equipment?
    public let updatedEquipment: Equipment?
    public let id: UUID
    public let routineID: UUID
    public let date: Date
    public let origin: String
    public let previous: ExercisePrescription?
    public let updated: ExercisePrescription?
}

extension CoordinatedModelStore {
    public func prescriptionChanges() throws -> [PrescriptionHistoryEntry] {
        try withContext { try Self.prescriptionChanges(in: $0) }
    }

    static func prescriptionChanges(in context: ModelContext) throws -> [PrescriptionHistoryEntry] {
        let records = try context.fetch(
            FetchDescriptor<TrainingSchemaV1.PrescriptionChange>(
                sortBy: [SortDescriptor(\.date, order: .reverse), SortDescriptor(\.id)])
        )
        guard !records.isEmpty else { return [] }
        let routineGyms = try Dictionary(
            uniqueKeysWithValues: context.fetch(FetchDescriptor<TrainingSchemaV1.Routine>()).map { ($0.id, $0.gymID) })
        var catalogs: [UUID: [UUID: PrescriptionHistoryEntry.Equipment]] = [:]
        for gym in try context.fetch(FetchDescriptor<TrainingSchemaV1.Gym>()) {
            var items = Dictionary(
                uniqueKeysWithValues: EquipmentDescription.genericOptions(in: gym.id).map {
                    ($0.id, PrescriptionHistoryEntry.Equipment.generic($0.kind))
                })
            for item in try gym.equipment { items[item.id] = .named(item.name) }
            catalogs[gym.id] = items
        }
        return try records.map { entry in
            let catalog = routineGyms[entry.routineID].flatMap { catalogs[$0] }
            func equipment(for exercise: ExercisePrescription?) -> PrescriptionHistoryEntry.Equipment? {
                exercise?.equipmentID.map { catalog?[$0] ?? .unavailable($0) }
            }
            let previous = try entry.previous
            let updated = try entry.updated
            return PrescriptionHistoryEntry(
                previousEquipment: equipment(for: previous), updatedEquipment: equipment(for: updated),
                id: entry.id, routineID: entry.routineID, date: entry.date,
                origin: entry.origin, previous: previous, updated: updated)
        }
    }
}
