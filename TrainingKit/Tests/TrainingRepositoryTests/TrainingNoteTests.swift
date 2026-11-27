import Foundation
import Testing
import TrainingRepositories

struct TrainingNoteTests {
    @Test func editsAreLocalUntilSavedAndStartFreshAfterReopening() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        func reopen() -> CoordinatedModelStore { CoordinatedModelStore(trainingDirectory: directory) }
        let date = Date(timeIntervalSince1970: 1800)
        let fixture = try #require(
            Bundle.module.url(forResource: "closed-session-v2", withExtension: "store", subdirectory: "Fixtures"))
        try FileManager.default.copyItem(at: fixture, to: directory.appendingPathComponent("training.store"))
        let session = try #require(try reopen().workoutHistory().sessions.first)
        var newNote = NoteEdit(date: date, sessionID: session.id)
        let first = "  Más control\nmañana. "
        newNote.update(first)
        try reopen().saveNote(newNote)
        try reopen().saveNote(newNote)
        let savedNotes = try reopen().notes(sessionID: session.id)
        #expect(savedNotes.count == 1)
        let saved = try #require(savedNotes.first)
        #expect(saved.date == date && saved.text == first)
        var edit = NoteEdit(note: saved)
        #expect(!edit.canUndo && !edit.canRedo)
        edit.update("Second")
        edit.undo()
        #expect(edit.text == first)
        edit.redo()
        #expect(edit.text == "Second")
        edit.update(nil)
        edit.undo()
        #expect(edit.text == "Second")
        edit.update("Final")
        #expect(!edit.canRedo)
        #expect(try reopen().notes().first?.text == first)
        try reopen().saveNote(edit)
        var stale = NoteEdit(note: saved)
        stale.update("Stale")
        #expect(throws: NoteEditError.changedSinceOpening) { try reopen().saveNote(stale) }
        let final = try #require(try reopen().notes().first)
        var deletion = NoteEdit(note: final)
        #expect(!deletion.canUndo && final.text == "Final" && final.date == date)
        deletion.update(nil)
        deletion.undo()
        deletion.redo()
        try reopen().saveNote(deletion)
        try reopen().saveNote(deletion)
        #expect(try reopen().notes().isEmpty)
    }
}
