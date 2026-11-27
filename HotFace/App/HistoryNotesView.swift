import SwiftUI
import TrainingRepositories

struct HistoryNotesView: View {
    let sessionID: UUID?
    @State private var notes: [TrainingNote] = []
    @State private var editor: NoteEdit?
    @State private var failed = false

    var body: some View {
        List {
            if failed {
                Button("Could not load notes. Try again", action: reload)
            } else if notes.isEmpty {
                ContentUnavailableView("No notes yet", systemImage: "note.text")
            } else {
                ForEach(notes) { note in
                    Button {
                        editor = NoteEdit(note: note)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(note.date, format: .dateTime.day().month().year().hour().minute())
                                .font(.caption).foregroundStyle(.secondary)
                            Text(verbatim: note.text).lineLimit(3)
                        }
                    }.buttonStyle(.plain)
                }
            }
        }
        .navigationTitle(sessionID == nil ? "Notes" : "Session notes")
        .toolbar { Button("Add note", systemImage: "plus") { editor = NoteEdit(date: .now, sessionID: sessionID) } }
        .onAppear(perform: reload)
        .sheet(item: $editor, onDismiss: reload) { edit in HistoryNoteEditor(edit: edit) }
    }

    private func reload() {
        do {
            notes = try TrainingStorage.openStore().notes(sessionID: sessionID)
            failed = false
        } catch { failed = true }
    }
}

private struct HistoryNoteEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var edit: NoteEdit
    @State private var failed = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if edit.text != nil {
                        TextEditor(text: Binding(get: { edit.text ?? "" }, set: { edit.update($0) }))
                            .accessibilityLabel("Note text").frame(minHeight: 140)
                    } else {
                        Text("This note will be deleted when you save.")
                    }
                } header: {
                    Text(edit.date, format: .dateTime.day().month().year().hour().minute())
                }
                Section {
                    Button("Undo") { edit.undo() }.disabled(!edit.canUndo)
                    Button("Redo") { edit.redo() }.disabled(!edit.canRedo)
                    if edit.original != nil && edit.text != nil {
                        Button("Delete note", role: .destructive) { edit.update(nil) }
                    }
                }
            }
            .navigationTitle(edit.original == nil ? "Add note" : "Edit note")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do {
                            try TrainingStorage.openStore().saveNote(edit)
                            dismiss()
                        } catch { failed = true }
                    }.disabled(!edit.canSave)
                }
            }
            .alert("Could not save note", isPresented: $failed) { Button("OK") {} }
        }
    }
}
