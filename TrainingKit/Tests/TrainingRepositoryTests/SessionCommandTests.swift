import Foundation
import SwiftData
import Testing
import TrainingDomain
import TrainingRepositories

private typealias V1 = TrainingSchemaV1

private struct FixedClock: WorkoutClock {
    let now: Date
    init(_ seconds: TimeInterval) { now = Date(timeIntervalSinceReferenceDate: seconds) }
}

private struct Fixture {
    let directory: URL
    let exercise = ExercisePrescription(name: "Curl", sets: 2, segments: [.repetitions(10)])
    let performance = SetPerformance(segments: [.repetitions(9)])
    let sessionID = UUID()
    let start: SessionCommand
    var store: CoordinatedModelStore { CoordinatedModelStore(trainingDirectory: directory) }

    init(withExistingSet: Bool = false) throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let day = RoutineDay(name: "A", exercises: [exercise])
        // Seed a real V1 store, as it would exist before installing the command-capable repository.
        let oldStore = CoordinatedModelStore(schema: Schema(versionedSchema: V1.self),
                                             storeURL: directory.appendingPathComponent("training.store"),
                                             lockURL: directory.appendingPathComponent("training.lock"))
        let sessionID = self.sessionID
        let exercise = self.exercise
        let performance = self.performance
        let action = try oldStore.withContext { context in
            let gym = try V1.Gym(name: "Gym")
            let routine = try V1.Routine(gymID: gym.id, plan: RoutinePlan(name: "Plan", days: [day]))
            let cycle = V1.Cycle(routineID: routine.id, orderedDayIDs: [day.id])
            context.insert(gym)
            context.insert(routine)
            context.insert(cycle)
            if withExistingSet {
                let session = try V1.Session(id: sessionID, routine: routine, gym: gym, dayID: day.id,
                                             cycle: cycle, startedAt: FixedClock(10).now)
                context.insert(session)
                context.insert(try V1.PerformedSet(sessionID: sessionID, exerciseID: exercise.id, number: 1,
                                                   performedAt: FixedClock(20).now, performance: performance))
            }
            try context.save()
            return SessionCommand.Action.start(routineID: routine.id, gymID: gym.id, dayID: day.id, cycleID: cycle.id)
        }
        start = SessionCommand(sessionID: sessionID, action: action)
    }

    func command(_ action: SessionCommand.Action) -> SessionCommand {
        SessionCommand(sessionID: sessionID, action: action)
    }

    func complete(_ number: Int) -> SessionCommand {
        command(.completeSet(exerciseID: exercise.id, number: number, performance: performance))
    }

    func applyAndRetry(_ command: SessionCommand, at seconds: TimeInterval) throws {
        #expect(try store.apply(command, clock: FixedClock(seconds)) == .applied)
        #expect(try store.apply(command, clock: FixedClock(seconds + 86400)) == .alreadyApplied)
        // Two taps can have different command identifiers but still target the same transition.
        #expect(try store.apply(self.command(command.action), clock: FixedClock(seconds + 86400)) == .alreadyApplied)
    }
}

struct SessionCommandTests {
    @Test func recoversEveryTransitionAndIgnoresRepeatedTaps() throws {
        let f = try Fixture()
        defer { try? FileManager.default.removeItem(at: f.directory) }

        try f.applyAndRetry(f.start, at: 100)
        try f.store.withContext { context in
            let sessions = try context.fetch(FetchDescriptor<V1.Session>())
            #expect(sessions.count == 1)
            let session = try #require(sessions.first)
            #expect(session.id == f.sessionID && session.startedAt == FixedClock(100).now && session.finishedAt == nil)
            #expect(try session.prescription.day.exercises == [f.exercise])
        }

        let complete = f.complete(1)
        try f.applyAndRetry(complete, at: 200)
        try f.store.withContext { context in
            let sets = try context.fetch(FetchDescriptor<V1.PerformedSet>())
            #expect(sets.count == 1)
            let set = try #require(sets.first)
            #expect(set.number == 1 && set.performedAt == FixedClock(200).now)
            #expect(try set.performance == f.performance)
        }

        let rate = f.command(.rate(exerciseID: f.exercise.id, effort: .hard))
        try f.applyAndRetry(rate, at: 300)
        try f.store.withContext { context in
            let ratings = try context.fetch(FetchDescriptor<V1.Rating>())
            #expect(ratings.count == 1)
            let rating = try #require(ratings.first)
            #expect(rating.effort == .hard && rating.date == FixedClock(300).now)
        }

        try f.applyAndRetry(f.command(.skip(exerciseID: f.exercise.id)), at: 400)
        try f.store.withContext { context in
            let session = try #require(context.fetch(FetchDescriptor<V1.Session>()).first)
            #expect(session.skippedExerciseIDs == [f.exercise.id] && session.finishedAt == nil)
            let cycle = try #require(context.fetch(FetchDescriptor<V1.Cycle>()).first)
            #expect(cycle.completedDayIDs.isEmpty)
        }

        try f.applyAndRetry(f.command(.finish), at: 86400)
        #expect(try f.store.apply(complete, clock: FixedClock(90000)) == .alreadyApplied)
        #expect(try f.store.apply(rate, clock: FixedClock(90000)) == .alreadyApplied)
        #expect(throws: SessionCommandError.sessionClosed) {
            try f.store.apply(f.complete(2), clock: FixedClock(90000))
        }
        try f.store.withContext { context in
            let session = try #require(context.fetch(FetchDescriptor<V1.Session>()).first)
            let cycle = try #require(context.fetch(FetchDescriptor<V1.Cycle>()).first)
            #expect(session.finishedAt == FixedClock(86400).now && session.isPartial)
            #expect(try cycle.completedDayIDs == [session.prescription.day.id])
            #expect(try context.fetchCount(FetchDescriptor<V1.PerformedSet>()) == 1)
            #expect(try context.fetchCount(FetchDescriptor<V1.Rating>()) == 1)
        }
    }

    @Test func resumesAnOpenV1SessionWithoutCommandReceipts() throws {
        let f = try Fixture(withExistingSet: true)
        defer { try? FileManager.default.removeItem(at: f.directory) }
        #expect(try f.store.apply(f.start, clock: FixedClock(100)) == .alreadyApplied)
        #expect(try f.store.apply(f.complete(1), clock: FixedClock(110)) == .alreadyApplied)
        try f.applyAndRetry(f.complete(2), at: 120)
        try f.store.withContext { context in
            let sets = try context.fetch(FetchDescriptor<V1.PerformedSet>(sortBy: [SortDescriptor(\.number)]))
            #expect(sets.map(\.performedAt) == [FixedClock(20).now, FixedClock(120).now])
            #expect(sets.allSatisfy { $0.sessionID == f.sessionID })
        }
    }

    @Test func concurrentWritersPreserveDistinctSetsAndRejectConflicts() async throws {
        let f = try Fixture()
        defer { try? FileManager.default.removeItem(at: f.directory) }
        let clock = FixedClock(100)
        let first = f.complete(1)
        #expect(throws: SessionCommandError.sessionNotFound) { try f.store.apply(first, clock: clock) }
        _ = try f.store.apply(f.start, clock: clock)

        let results: [SessionCommandResult] = try await withThrowingTaskGroup(of: SessionCommandResult.self) { group in
            for command in [first, first, f.complete(1), f.complete(2)] {
                group.addTask { try f.store.apply(command, clock: clock) }
            }
            return try await group.reduce(into: []) { $0.append($1) }
        }
        #expect(results.filter { $0 == .applied }.count == 2)
        #expect(results.filter { $0 == .alreadyApplied }.count == 2)

        let collision = SessionCommand(id: first.id, sessionID: f.sessionID, action: .finish)
        #expect(throws: SessionCommandError.conflictingIdentifier) { try f.store.apply(collision, clock: clock) }
        let changed = f.command(.completeSet(exerciseID: f.exercise.id, number: 1, performance: SetPerformance(segments: [])))
        #expect(throws: SessionCommandError.conflictingSet) { try f.store.apply(changed, clock: clock) }

        try f.applyAndRetry(f.command(.finish), at: 200)
        try f.store.withContext { context in
            let session = try #require(context.fetch(FetchDescriptor<V1.Session>()).first)
            #expect(!session.isPartial && session.finishedAt == FixedClock(200).now)
            let sets = try context.fetch(FetchDescriptor<V1.PerformedSet>())
            #expect(sets.map(\.number).sorted() == [1, 2])
        }
    }
}
