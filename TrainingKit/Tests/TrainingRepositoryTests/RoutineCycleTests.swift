import Foundation
import Testing
import TrainingDomain
import TrainingRepositories

struct RoutineCycleTests {
    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @Test func temporaryOrderAndSkippedDaysResetInNextCycleAcrossDates() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        func store() -> CoordinatedModelStore { CoordinatedModelStore(trainingDirectory: directory) }
        let gymID = try #require(store().createGym(name: "Gym").activeGymID)
        var routine = ManualRoutine(gymID: gymID)
        routine.plan = RoutinePlan(
            name: "Plan",
            days: ["A", "B", "C"].map {
                RoutineDay(name: $0, exercises: [ExercisePrescription(name: $0, segments: [.repetitions(8)])])
            })
        try store().saveRoutine(routine)
        routine = try #require(try store().activeRoutine())
        let ids = routine.plan.days.map(\.id)
        let cycle = try store().currentCycle(for: routine.id)
        let reordered = try store().reorderDays(in: cycle.id, to: [ids[2], ids[0], ids[1]])
        #expect(reordered.availableDayIDs == [ids[2], ids[0], ids[1]])
        let afterSkip = try store().skipDay(ids[0], in: cycle.id)
        #expect(afterSkip.skippedDayIDs == [ids[0]])

        let firstSession = UUID()
        let firstClock = TestWorkoutClock(Date(timeIntervalSince1970: 100))
        _ = try store().apply(
            SessionCommand(
                sessionID: firstSession,
                action: .start(
                    routineID: routine.id, gymID: gymID, dayID: ids[2], cycleID: cycle.id)), clock: firstClock)
        _ = try store().apply(SessionCommand(sessionID: firstSession, action: .finish), clock: firstClock)
        let secondSession = UUID()
        let secondClock = TestWorkoutClock(Date(timeIntervalSince1970: 86_500))
        _ = try store().apply(
            SessionCommand(
                sessionID: secondSession,
                action: .start(
                    routineID: routine.id, gymID: gymID, dayID: ids[1], cycleID: cycle.id)), clock: secondClock)
        _ = try store().apply(SessionCommand(sessionID: secondSession, action: .finish), clock: secondClock)

        let next = try store().currentCycle(for: routine.id)
        #expect(next.id != cycle.id)
        #expect(next.orderedDayIDs == ids)
        #expect(next.availableDayIDs == ids)
        #expect(try store().activeRoutine()?.id == routine.id)
    }

    @Test func usualOrderIsSavedForFutureCycles() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        func store() -> CoordinatedModelStore { CoordinatedModelStore(trainingDirectory: directory) }
        let gymID = try #require(store().createGym(name: "Gym").activeGymID)
        var draft = ManualRoutine(gymID: gymID)
        draft.plan = RoutinePlan(
            name: "Plan",
            days: ["A", "B"].map {
                RoutineDay(name: $0, exercises: [ExercisePrescription(name: $0, segments: [.repetitions(8)])])
            })
        try store().saveRoutine(draft)
        let routine = try #require(try store().activeRoutine())
        let ids = routine.plan.days.map(\.id)
        let cycle = try store().currentCycle(for: routine.id)
        _ = try store().reorderDays(in: cycle.id, to: ids.reversed(), keepForFutureCycles: true)
        let next = try store().currentCycle(for: routine.id)
        #expect(next.orderedDayIDs == Array(ids.reversed()))
    }
}

private struct TestWorkoutClock: WorkoutClock {
    let now: Date
    init(_ now: Date) { self.now = now }
}
