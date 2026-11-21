import Foundation
import SwiftData

public struct CoordinatedModelStore {
    private let schema: Schema
    private let storeURL: URL
    private let lockURL: URL

    public init(model: any PersistentModel.Type, storeURL: URL, lockURL: URL) {
        self.init(schema: Schema([model]), storeURL: storeURL, lockURL: lockURL)
    }

    public init(schema: Schema, storeURL: URL, lockURL: URL) {
        self.schema = schema
        self.storeURL = storeURL
        self.lockURL = lockURL
    }

    public func withContext<T>(_ operation: (ModelContext) throws -> T) throws -> T {
        // Coordinate the whole read/check/save, including first-time store creation.
        // All processes use the same lock URL and open a fresh context inside it.
        var result: Result<T, Error>?
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: lockURL, options: [], error: &coordinationError) { _ in
            result = Result {
                let configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
                let container = try ModelContainer(for: schema, configurations: [configuration])
                return try operation(ModelContext(container))
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw CocoaError(.fileWriteUnknown) }
        return try result.get()
    }
}
