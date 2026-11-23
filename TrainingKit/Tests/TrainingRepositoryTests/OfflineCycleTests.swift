import Foundation
import Testing
import TrainingDomain
import TrainingRepositories

struct OfflineCycleTests {
    @Test func reviewsCompleteAndPartialDaysAfterStartingTheNextCycle() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        func reopen() -> CoordinatedModelStore { CoordinatedModelStore(trainingDirectory: directory) }

        let gymID = try #require(reopen().createGym(name: "Offline gym").activeGymID)
        let pull = ExercisePrescription(name: "Pull", sets: 2, segments: [.toFailure])
        let squat = ExercisePrescription(name: "Squat", sets: 3, segments: [.repetitions(8)])
        let days = [RoutineDay(name: "Pull day", exercises: [pull]), RoutineDay(name: "Leg day", exercises: [squat])]
        var routine = ManualRoutine(gymID: gymID)
        routine.plan = RoutinePlan(name: "Two days", days: days)
        try reopen().saveRoutine(routine)
        let cycle = try reopen().currentCycle(for: routine.id)
        var time = Date(timeIntervalSinceReferenceDate: 0)
        func perform(_ action: SessionCommand.Action, in id: UUID) throws {
            time.addTimeInterval(1)
            _ = try reopen().apply(SessionCommand(sessionID: id, action: action), clock: CycleClock(now: time))
        }
        func start(_ day: RoutineDay) throws -> UUID {
            let id = UUID()
            try perform(.start(routineID: routine.id, gymID: gymID, dayID: day.id, cycleID: cycle.id), in: id)
            return id
        }
        let first = try start(days[0])
        let failure = SetPerformance(asPrescribed: pull)
        try perform(.logSet(exerciseID: pull.id, number: 1, performance: failure), in: first)
        let rest = try #require(try reopen().openWorkout()?.rest)
        try perform(.correctSet(id: rest.id, performance: .init(segments: [.repetitions(12)])), in: first)
        try perform(.logSet(exerciseID: pull.id, number: 2, performance: failure), in: first)
        #expect(try reopen().currentCycle(for: routine.id).availableDayIDs == [days[1].id])

        let second = try start(days[1])
        try perform(.logSet(exerciseID: squat.id, number: 1, performance: .init(asPrescribed: squat)), in: second)
        time.addTimeInterval(86400)
        #expect(try reopen().openWorkout()?.id == second)
        try perform(.finish, in: second)
        try perform(.rateFinished(exerciseID: squat.id, effort: .easy), in: second)
        let next = try reopen().currentCycle(for: routine.id)
        #expect(next.id != cycle.id && next.availableDayIDs == days.map(\.id))
        #expect(try reopen().openWorkout() == nil)

        let full = try reopen().workoutSummary(id: first)
        #expect(
            !full.partial && full.exercises[0].sets.map(\.performance.segments) == [[.repetitions(12)], [.toFailure]])
        let partial = try reopen().workoutSummary(id: second)
        #expect(partial.partial && partial.exercises[0].unperformed == 2)
        #expect(partial.exercises[0].effort == .easy)
    }
}

private struct CycleClock: WorkoutClock {
    let now: Date
}
