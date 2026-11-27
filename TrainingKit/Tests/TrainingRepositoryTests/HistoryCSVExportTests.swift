import Foundation
import Testing
import TrainingDomain
import TrainingRepositories

struct HistoryCSVExportTests {
    @Test func partialWorkoutExportsRelatedRowsInRecordedUnits() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CoordinatedModelStore(trainingDirectory: directory)
        let gym = try #require(store.createGym(name: "Gym, North").activeGymID)
        let press = ExercisePrescription(name: "Press", sets: 4, segments: [.toFailure])
        let skip = ExercisePrescription(name: "Plank", sets: 1, segments: [.seconds(30)])
        let day = RoutineDay(name: "Day", exercises: [press, skip])
        var routine = ManualRoutine(gymID: gym)
        routine.plan = RoutinePlan(name: "A \"heavy\" day", days: [day])
        try store.saveRoutine(routine)
        let id = UUID()
        func apply(_ action: SessionCommand.Action, _ time: TimeInterval) throws {
            _ = try store.apply(
                .init(sessionID: id, action: action), clock: ExportClock(now: Date(timeIntervalSince1970: time)))
        }
        try apply(.start(routineID: routine.id, gymID: gym, dayID: day.id, cycleID: nil), 100)
        let zero = ExerciseLoad(amount: 0, unit: .lb, representation: .combined, implementCount: 1)
        let kg = ExerciseLoad(amount: 12.5, unit: .kg, representation: .perImplement, implementCount: 2)
        for (i, actual) in [
            SetPerformance(segments: [.repetitions(0)], load: zero),
            SetPerformance(segments: [.toFailure]),
            SetPerformance(segments: [.repetitions(10)], load: kg),
        ].enumerated() {
            try apply(.completeSet(exerciseID: press.id, number: i + 1, performance: actual), Double(101 + i))
        }
        try apply(.skip(exerciseID: skip.id), 105)
        try apply(.finish, 160)
        var edit = try #require(try store.routine(id: routine.id))
        edit.plan.days[0].exercises[0].load = .confirmed(kg)
        try store.saveRoutine(edit, at: Date(timeIntervalSince1970: 200))
        var note = NoteEdit(date: Date(timeIntervalSince1970: 201), sessionID: id)
        note.update("control, \"sí\"\r\nsegunda línea")
        try store.saveNote(note)

        let files = try store.exportHistoryCSV()
        #expect(try CoordinatedModelStore(trainingDirectory: directory).exportHistoryCSV() == files)
        let csv = Dictionary(uniqueKeysWithValues: files.map { ($0.name, String(decoding: $0.data, as: UTF8.self)) })
        #expect(Set(csv.keys) == ["sessions.csv", "exercises.csv", "sets.csv", "changes.csv", "notes.csv"])
        let sessions = try #require(csv["sessions.csv"])
        #expect(
            sessions.contains(
                ",60.0,partial,\(gym.uuidString),\"Gym, North\",\(routine.id.uuidString),\"A \"\"heavy\"\" day\""))
        #expect(sessions.contains("1970-01-01T00:01:40.000Z"))
        let exercises = try #require(csv["exercises.csv"])
        #expect(exercises.contains("\(id.uuidString),1,,,false,,\(press.id.uuidString),Press"))
        let setText = try #require(csv["sets.csv"])
        let rows = setText.components(separatedBy: "\r\n").filter { !$0.isEmpty }.map {
            $0.components(separatedBy: ",")
        }
        #expect(rows.count == 6)
        #expect(rows.allSatisfy { $0.count == rows[0].count })
        #expect(Array(rows[1].prefix(3)) == [id.uuidString, press.id.uuidString, "1"])
        #expect(UUID(uuidString: rows[1][3]) != nil)
        #expect(Array(rows[1].suffix(8)) == ["completed", "reps:0", "", "false", "0", "lb", "combined", "1"])
        #expect(Array(rows[2].suffix(8)) == ["completed", "failure", "", "false", "", "", "", ""])
        #expect(Array(rows[3].suffix(4)) == ["12.5", "kg", "perImplement", "2"])
        #expect(rows[4][3].isEmpty && rows[4][5] == "unperformed")
        #expect(rows[5][1] == skip.id.uuidString && rows[5][5] == "skipped")
        let changes = try #require(csv["changes.csv"])
        let change = try #require(store.prescriptionChanges().first)
        let key = "\(change.id.uuidString),\(routine.id.uuidString),1970-01-01T00:03:20.000Z,routine,"
        #expect(changes.contains(key + "previous,\(press.id.uuidString),Press"))
        #expect(changes.contains(key + "final,\(press.id.uuidString),Press"))
        #expect(changes.hasSuffix("confirmed,12.5,kg,perImplement,2\r\n"))
        let notes = try #require(csv["notes.csv"])
        #expect(notes.hasSuffix("\(id.uuidString),,\"control, \"\"sí\"\"\r\nsegunda línea\"\r\n"))
    }
}

private struct ExportClock: WorkoutClock {
    let now: Date
}
