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
        #if targetEnvironment(simulator)
            if let value = ProcessInfo.processInfo.environment["HOTFACE_UI_TEST_STORE_ID"],
                let id = UUID(uuidString: value)
            {
                let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
                    id.uuidString, isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                return CoordinatedModelStore(trainingDirectory: directory)
            }
        #endif
        let directory = try applicationSupportDirectory().appendingPathComponent("Training", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return CoordinatedModelStore(trainingDirectory: directory)
    }
}
