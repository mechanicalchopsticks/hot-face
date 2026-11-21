import Foundation
import TrainingRepositories

enum TrainingStorage {
    static func applicationSupportDirectory() throws -> URL {
        guard
            let group = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: "group.ejemplo.entrenamiento.prueba")
        else { throw CocoaError(.fileNoSuchFile) }
        return group.appendingPathComponent("Library/Application Support", isDirectory: true)
    }

    static func openStore() throws -> CoordinatedModelStore {
        let directory = try applicationSupportDirectory().appendingPathComponent("Training", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return CoordinatedModelStore(trainingDirectory: directory)
    }
}
