import Foundation
import TrainingDomain

public struct HistoryCSVFile: Equatable, Sendable {
    public let name: String
    public let data: Data
}

extension CoordinatedModelStore {
    public func exportHistoryCSV() throws -> [HistoryCSVFile] {
        // Read all tables under the same lock so concurrent edits cannot split the export.
        let (history, changes, notes) = try withContext { context in
            try (Self.workoutHistory(in: context), Self.prescriptionChanges(in: context), Self.notes(in: context))
        }
        var export = HistoryTables()
        for session in history.sessions { export.append(session) }
        for change in changes {
            let common = [change.id.uuidString, change.routineID.uuidString, timestamp(change.date), change.origin]
            if let previous = change.previous {
                export.changes.append(common + ["previous"] + prescriptionFields(previous))
            }
            if let updated = change.updated { export.changes.append(common + ["final"] + prescriptionFields(updated)) }
        }
        for note in notes {
            export.notes.append([
                note.id.uuidString, timestamp(note.date), note.sessionID?.uuidString,
                note.exerciseID?.uuidString, note.text,
            ])
        }
        return [export.sessions, export.exercises, export.sets, export.changes, export.notes].map(\.file)
    }
}

private struct CSVTable {
    let name: String
    var contents = ""

    init(_ name: String, _ columns: [String]) {
        self.name = name
        append(columns)
    }

    mutating func append(_ cells: [String?]) {
        let fields = cells.map { value -> String in
            guard let value else { return "" }
            guard value.rangeOfCharacter(from: Self.specialCharacters) != nil else { return value }
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        contents += fields.joined(separator: ",") + "\r\n"
    }

    private static let specialCharacters = CharacterSet(charactersIn: ",\"\r\n")
    var file: HistoryCSVFile { HistoryCSVFile(name: name, data: Data(contents.utf8)) }
}

private func timestamp(_ value: Date) -> String {
    value.ISO8601Format(.init(includingFractionalSeconds: true))
}

private func segmentField(_ values: [ExerciseSegment]) -> String {
    values.map { segment in
        switch segment {
        case .seconds(let n): "seconds:\(n)"
        case .repetitions(let n): "reps:\(n)"
        case .toFailure: "failure"
        }
    }.joined(separator: "|")
}

private let loadColumns = ["load_amount", "load_unit", "load_representation", "implement_count"]
private let prescriptionColumns =
    [
        "exercise_id", "exercise_name", "equipment_id", "station", "exercise_group", "variant", "band_color",
        "instructions", "set_count", "segments", "per_side", "load_status",
    ] + loadColumns

private func loadFields(_ load: ExerciseLoad?) -> [String?] {
    guard let load else { return [nil, nil, nil, nil] }
    return [
        NSDecimalNumber(decimal: load.amount).stringValue, load.unit.rawValue,
        load.representation.rawValue, String(load.implementCount),
    ]
}

private func prescriptionFields(_ value: ExercisePrescription) -> [String?] {
    return [
        value.id.uuidString, value.name, value.equipmentID?.uuidString, value.station, value.group,
        value.variant, value.bandColor?.rawValue, value.instructions, value.sets.map(String.init),
        segmentField(value.segments), String(value.perSide), value.load.status.rawValue,
    ] + loadFields(value.load.value)
}

private struct HistoryTables {
    var sessions = CSVTable(
        "sessions.csv",
        [
            "session_id", "started_at", "finished_at", "duration_seconds", "status",
            "gym_id", "gym_name", "routine_id", "routine_name", "routine_revision", "day_id", "day_name",
        ])
    var exercises = CSVTable(
        "exercises.csv",
        [
            "session_id", "position", "equipment_name", "equipment_station",
            "skipped", "effort",
        ] + prescriptionColumns)
    var sets = CSVTable(
        "sets.csv",
        [
            "session_id", "exercise_id", "set_number", "set_id", "performed_at", "status",
            "segments", "second_side_segments", "per_side",
        ] + loadColumns)
    var changes = CSVTable(
        "changes.csv", ["change_id", "routine_id", "changed_at", "origin", "stage"] + prescriptionColumns)
    var notes = CSVTable("notes.csv", ["note_id", "created_at", "session_id", "exercise_id", "text"])

    mutating func append(_ session: WorkoutSummary) {
        let snapshot = session.snapshot
        let id = session.id.uuidString
        sessions.append([
            id, timestamp(session.startedAt), timestamp(session.finishedAt),
            session.duration >= 0 ? String(session.duration) : nil, session.partial ? "partial" : "complete",
            snapshot.gymID.uuidString, snapshot.gymName, snapshot.routineID.uuidString, snapshot.routineName,
            String(snapshot.routineRevision), snapshot.day.id.uuidString, snapshot.day.name,
        ])
        for (index, exercise) in session.exercises.enumerated() {
            let value = exercise.prescription
            let item = snapshot.equipment.first { $0.id == value.equipmentID }
            exercises.append(
                [id, String(index + 1), item?.name, item?.station, String(exercise.skipped), exercise.effort?.rawValue]
                    + prescriptionFields(value))
            let recorded = Dictionary(grouping: exercise.sets, by: \.number)
            let count = max(value.sets ?? 0, exercise.sets.last?.number ?? 0)
            for index in 0..<count {
                let number = index + 1
                let key = [id, value.id.uuidString, String(number)]
                if let actuals = recorded[number] {
                    for set in actuals {
                        let p = set.performance
                        sets.append(
                            key + [
                                set.id.uuidString, timestamp(set.performedAt), p.isPartial ? "partial" : "completed",
                                segmentField(p.segments), p.secondSideSegments.map(segmentField), String(p.perSide),
                            ] + loadFields(p.load))
                    }
                } else {
                    sets.append(
                        key + [nil, nil, exercise.skipped ? "skipped" : "unperformed", nil, nil, nil] + loadFields(nil))
                }
            }
        }
    }
}
