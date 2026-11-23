import Foundation
import SwiftData
import Testing
import TrainingDomain
import TrainingRepositories

private struct DeletionClock: WorkoutClock {
    let now = Date(timeIntervalSinceReferenceDate: 2000)
}

struct CatalogDeletionTests {
    private func withFrozenCatalog(_ test: (CoordinatedModelStore) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fixture = try #require(
            Bundle.module.url(forResource: "active-gym-v4", withExtension: "store", subdirectory: "Fixtures"))
        try FileManager.default.copyItem(at: fixture, to: directory.appendingPathComponent("training.store"))
        // Each repository operation reopens the on-disk store under the shared lock.
        try test(CoordinatedModelStore(trainingDirectory: directory))
    }

    @Test func deletesGymsWithoutLosingArchivedRoutinesOrTheirHistory() throws {
        try withFrozenCatalog { store in
            let original = try #require(try store.activeRoutine())
            let gym = original.gymID
            let catalog = try store.gymCatalog()
            let south = try #require(catalog.gyms.first { $0.id != gym })
            let day = try #require(original.plan.days.first)
            let session = UUID()
            func apply(_ action: SessionCommand.Action) throws {
                _ = try store.apply(SessionCommand(sessionID: session, action: action), clock: DeletionClock())
            }
            #expect(throws: GymProfileError.invalidReplacement) { try store.deleteGym(gym) }
            #expect(throws: GymProfileError.invalidReplacement) { try store.deleteGym(gym, replacingWith: gym) }
            try apply(.start(routineID: original.id, gymID: gym, dayID: day.id, cycleID: nil))
            #expect(throws: RoutineEditorError.openSession(session)) { try store.checkGymDeletion(gym) }
            #expect(throws: RoutineEditorError.openSession(session)) {
                try store.deleteGym(gym, replacingWith: south.id)
            }
            _ = try store.deleteGym(south.id)
            #expect(try store.gymCatalog().gyms.map(\.id) == [gym])
            #expect(try store.activeRoutine()?.id == original.id)
            let replacement = try #require(store.createGym(name: south.name).gyms.first { $0.id != gym })
            #expect(replacement.id != south.id)
            try apply(.finish)
            try store.checkGymDeletion(gym)
            _ = try store.deleteGym(gym, replacingWith: replacement.id)
            #expect(try store.gymCatalog().activeGymID == replacement.id)
            #expect(try store.activeRoutine() == nil)
            #expect(throws: GymProfileError.missingGym) { try store.selectGym(gym) }
            #expect(try store.archivedRoutines(in: gym).first?.plan == original.plan)
            #expect(try store.loadHistory(in: gym)["Curl"]?.load.amount == 35)
            try store.withContext { context in
                let history = try context.fetch(FetchDescriptor<TrainingSchemaV1.Session>()).map { try $0.prescription }
                #expect(history.allSatisfy { $0.gymName == "North Gym" && $0.equipment.first?.station == "A7" })
            }
            var final = ManualRoutine(gymID: replacement.id)
            final.plan = original.plan.copiedForNewRoutine()
            try store.saveRoutine(final)
            _ = try store.deleteGym(replacement.id)
            let empty = try store.gymCatalog()
            #expect(empty.gyms.isEmpty && empty.activeGymID == nil)
            #expect(try store.archivedRoutines(in: replacement.id).first?.id == final.id)
            let fresh = try #require(store.createGym(name: "North Gym").activeGymID)
            #expect(fresh != gym)
            #expect(try store.loadHistory(in: fresh)["Curl"] == nil)
        }
    }
}
