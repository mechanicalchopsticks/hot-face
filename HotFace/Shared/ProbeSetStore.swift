import Foundation
import SwiftData
import TrainingRepositories

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

    private var store: CoordinatedModelStore {
        CoordinatedModelStore(
            model: ProbeCompletedSet.self,
            storeURL: directory.appendingPathComponent("sets.store"),
            lockURL: directory.appendingPathComponent("writer.lock")
        )
    }

    func complete(_ number: Int, writer: String) throws -> Bool {
        try store.withContext { context in
            let matching = FetchDescriptor<ProbeCompletedSet>(predicate: #Predicate { $0.number == number })
            guard try context.fetchCount(matching) == 0 else { return false }
            context.insert(ProbeCompletedSet(number: number, writer: writer))
            try context.save()
            return true
        }
    }

    func completed() throws -> [(Int, String)] {
        try store.withContext { context in
            try context.fetch(FetchDescriptor<ProbeCompletedSet>(sortBy: [SortDescriptor(\.number)]))
                .map { ($0.number, $0.writer) }
        }
    }
}
