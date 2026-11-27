import Foundation
import SwiftData
import TrainingDomain

public struct PrescriptionHistoryEntry: Identifiable, Sendable {
    public let id: UUID
    public let routineID: UUID
    public let date: Date
    public let origin: String
    public let previous: ExercisePrescription
    public let updated: ExercisePrescription
}

extension CoordinatedModelStore {
    public func prescriptionChanges() throws -> [PrescriptionHistoryEntry] {
        try withContext { try Self.prescriptionChanges(in: $0) }
    }

    static func prescriptionChanges(in context: ModelContext) throws -> [PrescriptionHistoryEntry] {
        try context.fetch(
            FetchDescriptor<TrainingSchemaV1.PrescriptionChange>(
                sortBy: [SortDescriptor(\.date, order: .reverse), SortDescriptor(\.id)])
        ).map { entry in
            try PrescriptionHistoryEntry(
                id: entry.id, routineID: entry.routineID, date: entry.date,
                origin: entry.origin, previous: entry.previous, updated: entry.updated)
        }
    }
}
