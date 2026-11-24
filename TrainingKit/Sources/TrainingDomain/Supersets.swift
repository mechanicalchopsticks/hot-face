import Foundation

public enum SupersetEdit: Codable, Equatable, Sendable {
    case create(id: UUID, members: Set<UUID>, rounds: Int, rest: SupersetRest)
    case dissolve(id: UUID)
}

public enum SupersetError: Error, Equatable {
    case invalidMembers, incompatibleSetCounts
}

extension RoutineDay {
    public mutating func apply(_ edit: SupersetEdit, defaultSets: Int) throws {
        switch edit {
        case .create(let id, let members, let rounds, let rest):
            let indices = exercises.indices.filter { members.contains(exercises[$0].id) }
            guard members.count >= 2, indices.count == members.count,
                indices.allSatisfy({ exercises[$0].supersetID == nil }),
                !exercises.contains(where: { $0.supersetID == id })
            else { throw SupersetError.invalidMembers }
            guard rounds > 0 else { throw SupersetError.incompatibleSetCounts }
            // Keep inheritance when all members use the routine default. A mixed group needs one stable count.
            let inherits = rounds == defaultSets && indices.allSatisfy { exercises[$0].sets == nil }
            for index in indices {
                exercises[index].supersetID = id
                exercises[index].sets = inherits ? nil : rounds
            }
            if rest != SupersetRest() { supersetRests[id] = rest }
        case .dissolve(let id):
            guard exercises.contains(where: { $0.supersetID == id }) else { throw SupersetError.invalidMembers }
            for index in exercises.indices where exercises[index].supersetID == id {
                exercises[index].supersetID = nil
            }
            supersetRests[id] = nil
        }
    }

    public func validateSupersets(defaultSets: Int) throws {
        let groups = Dictionary(grouping: exercises, by: \.supersetID)
        for (id, members) in groups where id != nil {
            guard members.count >= 2 else { throw SupersetError.invalidMembers }
            guard Set(members.map { $0.sets ?? defaultSets }).count == 1 else {
                throw SupersetError.incompatibleSetCounts
            }
        }
    }

    public mutating func removeExercises(withIDs ids: Set<UUID>) {
        let affected = Set(exercises.filter { ids.contains($0.id) }.compactMap(\.supersetID))
        exercises.removeAll { ids.contains($0.id) }
        for id in affected {
            let remaining = exercises.indices.filter { exercises[$0].supersetID == id }
            if remaining.count < 2 {
                if let index = remaining.first { exercises[index].supersetID = nil }
                supersetRests[id] = nil
            }
        }
    }
}
