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

    @Test func deletingAssignedEquipmentPreservesTheOpenWorkoutAndSharedWeights() throws {
        try withFrozenCatalog { store in
            var routine = try #require(try store.activeRoutine())
            let catalog = try store.gymCatalog()
            let gym = try #require(catalog.gyms.first { $0.id == routine.gymID })
            let other = try #require(catalog.gyms.first { $0.id != gym.id })
            let item = try #require(gym.equipment.first)
            let spare = EquipmentDescription(name: "Rack", kind: .dumbbell, unit: .lb)
            _ = try store.saveEquipment(spare, in: gym.id)
            _ = try store.saveEquipment(item, in: other.id)
            let day = try #require(routine.plan.days.first)
            let exercise = try #require(day.exercises.first)
            let start = SessionCommand.Action.start(routineID: routine.id, gymID: gym.id, dayID: day.id, cycleID: nil)
            let session = UUID()
            func apply(_ action: SessionCommand.Action, to id: UUID) throws {
                _ = try store.apply(SessionCommand(sessionID: id, action: action), clock: DeletionClock())
            }
            try apply(start, to: session)
            _ = try store.deleteEquipment(item.id, in: gym.id)
            #expect(throws: GymProfileError.missingEquipment) {
                try store.saveEquipment(item, in: gym.id, updatingExisting: true)
            }
            let saved = try store.gymCatalog()
            let current = try #require(saved.gyms.first { $0.id == gym.id })
            #expect(current.inventory == gym.inventory && current.equipment == [spare])
            #expect(current.loadOptions(for: item.id).isEmpty)
            #expect(saved.gyms.first { $0.id == other.id }?.equipment == [item])
            #expect(try store.activeRoutine()?.plan == routine.plan)
            try apply(
                .completeSet(exerciseID: exercise.id, number: 1, performance: SetPerformance(asPrescribed: exercise)),
                to: session)
            try apply(.finish, to: session)
            let history = try #require(store.loadHistory(in: gym.id)["Curl"])
            #expect(history.station == "A7" && history.performedAt == DeletionClock().now)
            #expect(history.load.amount == 35 && history.load.unit == .kg)
            #expect(throws: SessionCommandError.missingEquipment) { try apply(start, to: UUID()) }
            routine.plan.days[0].exercises[0].equipmentID = spare.id
            routine.plan.days[0].exercises[0].load = .undefined
            try store.saveRoutine(routine)
            try apply(start, to: UUID())
        }
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
