import Foundation
import SwiftData

public struct TrainingNote: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let date: Date
    public let sessionID: UUID?
    public let exerciseID: UUID?
    public let text: String

    init(_ record: TrainingSchemaV1.Note) {
        id = record.id
        date = record.date
        sessionID = record.sessionID
        exerciseID = record.exerciseID
        text = record.text
    }
}

public struct NoteEdit: Identifiable, Sendable {
    public let id: UUID
    public let date: Date
    public let sessionID: UUID?
    public let original: TrainingNote?
    public private(set) var text: String?
    private var undoStack: [String?] = []
    private var redoStack: [String?] = []

    public init(note: TrainingNote) {
        id = note.id
        date = note.date
        sessionID = note.sessionID
        original = note
        text = note.text
    }

    public init(date: Date, sessionID: UUID? = nil) {
        id = UUID()
        self.date = date
        self.sessionID = sessionID
        original = nil
        text = ""
    }

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }
    public var canSave: Bool {
        guard let text else { return original != nil }
        return text != original?.text && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// A nil draft stages deletion. It can be undone until the editor saves.
    public mutating func update(_ value: String?) {
        guard value != text else { return }
        undoStack.append(text)
        redoStack.removeAll()
        text = value
    }

    public mutating func undo() {
        guard !undoStack.isEmpty else { return }
        redoStack.append(text)
        text = undoStack.removeLast()
    }

    public mutating func redo() {
        guard !redoStack.isEmpty else { return }
        undoStack.append(text)
        text = redoStack.removeLast()
    }
}

public enum NoteEditError: Error {
    case emptyText, changedSinceOpening
}

extension CoordinatedModelStore {
    public func notes(sessionID: UUID? = nil) throws -> [TrainingNote] {
        try withContext { try Self.notes(in: $0, sessionID: sessionID) }
    }

    static func notes(in context: ModelContext, sessionID: UUID? = nil) throws -> [TrainingNote] {
        var query = FetchDescriptor<TrainingSchemaV1.Note>(
            sortBy: [SortDescriptor(\.date, order: .reverse), SortDescriptor(\.id)])
        if let sessionID { query.predicate = #Predicate { $0.sessionID == sessionID } }
        return try context.fetch(query).map(TrainingNote.init)
    }

    public func saveNote(_ edit: NoteEdit) throws {
        try withContext { context in
            let id = edit.id
            let query = FetchDescriptor<TrainingSchemaV1.Note>(predicate: #Predicate { $0.id == id })
            let record = try context.fetch(query).first
            if record?.text == edit.text { return }
            guard record.map(TrainingNote.init) == edit.original else { throw NoteEditError.changedSinceOpening }
            if let text = edit.text {
                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw NoteEditError.emptyText
                }
                if let record {
                    record.text = text
                } else {
                    if let sessionID = edit.sessionID {
                        let query = FetchDescriptor<TrainingSchemaV1.Session>(
                            predicate: #Predicate { $0.id == sessionID && $0.finishedAt != nil })
                        guard try context.fetchCount(query) == 1 else { throw SessionCommandError.sessionNotFound }
                    }
                    context.insert(
                        TrainingSchemaV1.Note(id: id, date: edit.date, text: text, sessionID: edit.sessionID))
                }
            } else if let record {
                context.delete(record)
            }
            try context.save()
        }
    }
}
