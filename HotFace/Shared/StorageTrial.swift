import ActivityKit
import Foundation

struct StorageTrialAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {}
    let trialID: UUID
}

struct StorageTrial {
    enum Writer: String, Codable {
        case app, widget

        var other: Self { self == .app ? .widget : .app }
        var distinctSet: Int { self == .app ? 2 : 3 }
    }

    struct Receipt: Codable {
        let writer: Writer
        let bundle: String
        let pid: Int32
        let inserted: [Bool]
    }

    let store: ProbeSetStore

    static let commandNotification = "ejemplo.entrenamiento.prueba.storage-trial"

    static func trialsDirectory() throws -> URL {
        guard let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.ejemplo.entrenamiento.prueba") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return group.appendingPathComponent("Library/Application Support/StorageTrials")
    }

    static func pendingCommand() throws -> URL {
        try trialsDirectory().appendingPathComponent("pending-command")
    }

    init(id: UUID) throws {
        let directory = try Self.trialsDirectory().appendingPathComponent(id.uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        store = ProbeSetStore(directory: directory)
    }

    private func file(_ name: String) -> URL { store.directory.appendingPathComponent(name) }

    func submit(_ writer: Writer) throws {
        var inserted = [Bool]()
        for number in [1, writer.distinctSet] {
            // Both commands must be in flight before either may enter the store.
            let round = inserted.count
            try Data().write(to: file("\(writer.rawValue)-\(round).ready"), options: .atomic)
            try wait(for: "\(writer.other.rawValue)-\(round).ready")
            inserted.append(try store.complete(number, writer: writer.rawValue))
        }
        let receipt = Receipt(writer: writer, bundle: Bundle.main.bundleIdentifier ?? "", pid: getpid(), inserted: inserted)
        try JSONEncoder().encode(receipt).write(to: file("\(writer.rawValue).json"), options: .atomic)
    }

    func wait(for name: String) throws {
        let deadline = ProcessInfo.processInfo.systemUptime + 20
        while !FileManager.default.fileExists(atPath: file(name).path) {
            guard ProcessInfo.processInfo.systemUptime < deadline else {
                throw NSError(domain: "StorageTrial", code: 1, userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for \(name)"])
            }
            Thread.sleep(forTimeInterval: 0.01)
        }
    }

    func verify(replay: Bool) throws -> String {
        let receipts = try [Writer.app, .widget].map { writer in
            try JSONDecoder().decode(Receipt.self, from: Data(contentsOf: file("\(writer.rawValue).json")))
        }
        let app = receipts[0], widget = receipts[1]
        let rows = try store.completed()
        guard app.writer == .app, widget.writer == .widget, app.pid != widget.pid,
              app.bundle == "ejemplo.entrenamiento.prueba", widget.bundle == app.bundle + ".actividad",
              app.inserted.count == 2, widget.inserted.count == 2,
              app.inserted[0] != widget.inserted[0], app.inserted[1], widget.inserted[1],
              rows.map(\.0) == [1, 2, 3],
              rows.map(\.1) == [app.inserted[0] ? "app" : "widget", "app", "widget"] else {
            throw CocoaError(.fileReadCorruptFile)
        }
        if replay {
            guard getpid() != app.pid else { throw CocoaError(.executableRuntimeMismatch) }
            for row in rows {
                guard try !store.complete(row.0, writer: "retry") else { throw CocoaError(.fileReadCorruptFile) }
            }
            guard try store.completed().elementsEqual(rows, by: ==) else { throw CocoaError(.fileReadCorruptFile) }
        }
        return "app=\(app.pid) \(app.inserted), widget=\(widget.pid) \(widget.inserted), reader=\(getpid()), sets=\(rows), replay=\(replay)"
    }
}
