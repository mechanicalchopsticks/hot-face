import Foundation
import SwiftData

@Model
final class ProbeCompletedSet {
    @Attribute(.unique) var number: Int
    var writer: String

    init(number: Int, writer: String) {
        self.number = number
        self.writer = writer
    }
}

// Each trial directory represents one fictitious session.
struct ProbeSetStore {
    let directory: URL

    func complete(_ number: Int, writer: String) throws -> Bool {
        try withContext { context in
            let matching = FetchDescriptor<ProbeCompletedSet>(predicate: #Predicate { $0.number == number })
            guard try context.fetchCount(matching) == 0 else { return false }
            context.insert(ProbeCompletedSet(number: number, writer: writer))
            try context.save()
            return true
        }
    }

    func completed() throws -> [(Int, String)] {
        try withContext { context in
            try context.fetch(FetchDescriptor<ProbeCompletedSet>(sortBy: [SortDescriptor(\.number)]))
                .map { ($0.number, $0.writer) }
        }
    }

    private func withContext<T>(_ operation: (ModelContext) throws -> T) throws -> T {
        // Coordinate the whole read/check/save, including first-time store creation.
        // All processes use the same lock URL and open a fresh context inside it.
        var result: Result<T, Error>?
        var coordinationError: NSError?
        let lock = directory.appendingPathComponent("writer.lock")
        NSFileCoordinator().coordinate(writingItemAt: lock, options: [], error: &coordinationError) { _ in
            result = Result {
                let configuration = ModelConfiguration(url: directory.appendingPathComponent("sets.store"), cloudKitDatabase: .none)
                let container = try ModelContainer(for: ProbeCompletedSet.self, configurations: configuration)
                return try operation(ModelContext(container))
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw CocoaError(.fileWriteUnknown) }
        return try result.get()
    }
}
