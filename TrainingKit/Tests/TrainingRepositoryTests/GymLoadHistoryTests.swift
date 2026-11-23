import Foundation
import Testing
import TrainingDomain
import TrainingRepositories

private struct HistoryClock: WorkoutClock {
    let now: Date
}

struct GymLoadHistoryTests {
    @Test func findsTheLastPerformedWeightAcrossArchivedRoutines() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CoordinatedModelStore(trainingDirectory: directory)
        let gym = try #require(store.createGym(name: "A").activeGymID)
        let other = try #require(store.createGym(name: "B").gyms.first { $0.id != gym }?.id)

        func record(in gymID: UUID, name: String, weights: [Decimal?], at time: TimeInterval) throws {
            var exercise = ExercisePrescription(name: name, segments: Array(repeating: .repetitions(7), count: 3))
            exercise.instructions = "Slow return"
            exercise.station = "12"
            let day = RoutineDay(name: "A", exercises: [exercise])
            var routine = ManualRoutine(gymID: gymID)
            routine.plan = RoutinePlan(name: "Strength", days: [day])
            try store.saveRoutine(routine)
            let session = UUID()
            func apply(_ action: SessionCommand.Action, offset: Int = 0) throws {
                _ = try store.apply(
                    SessionCommand(sessionID: session, action: action),
                    clock: HistoryClock(now: Date(timeIntervalSinceReferenceDate: time + Double(offset))))
            }
            try apply(.start(routineID: routine.id, gymID: gymID, dayID: day.id, cycleID: nil))
            for (index, amount) in weights.enumerated() {
                let load = amount.map {
                    ExerciseLoad(amount: $0, unit: .kg, representation: .combined, implementCount: 1)
                }
                try apply(
                    .completeSet(
                        exerciseID: exercise.id, number: index + 1,
                        performance: SetPerformance(segments: [.repetitions(6)], load: load)), offset: index + 1)
            }
            if weights.isEmpty { try apply(.skip(exerciseID: exercise.id)) }
            try apply(.finish, offset: weights.count + 1)
        }

        try record(in: gym, name: "Curl", weights: [25], at: 10)
        try record(in: gym, name: "Curl", weights: [30, 35, nil], at: 20)
        try record(in: gym, name: "Curl", weights: [], at: 30)
        try record(in: gym, name: "Press", weights: [5, 0], at: 40)
        _ = try store.selectGym(other)
        try record(in: other, name: "Curl", weights: [40], at: 50)
        try record(in: other, name: "Row", weights: [10], at: 60)

        let history = try CoordinatedModelStore(trainingDirectory: directory).loadHistory(in: gym)
        let curl = try #require(history[" curl "])
        #expect(curl.load.amount == 35 && curl.load.unit == .kg)
        #expect(curl.performedAt == Date(timeIntervalSinceReferenceDate: 22))
        #expect(curl.exercise.sets == 4 && curl.exercise.segments == Array(repeating: .repetitions(7), count: 3))
        #expect(curl.station == "12" && curl.exercise.instructions == "Slow return")
        #expect(history["Press"]?.load.amount == 0)
        #expect(history["Row"] == nil)

        var exercise = ExercisePrescription(name: "Curl", sets: 3, segments: [.repetitions(8)])
        let suggestion = try #require(history.suggestion(for: exercise))
        #expect(exercise.load == .undefined)
        #expect(suggestion.confirmed(amount: 35) == .confirmed(curl.load))
        exercise.load = suggestion.confirmed(amount: 30)
        #expect(
            exercise.load
                == .confirmed(ExerciseLoad(amount: 30, unit: .kg, representation: .combined, implementCount: 1)))
        let copied = RoutinePlan(name: "Copy", days: [RoutineDay(name: "Day", exercises: [exercise])])
            .copiedForNewRoutine()
        let copiedExercise = try #require(copied.days.first?.exercises.first)
        #expect(history.suggestion(for: copiedExercise) == nil && copiedExercise.load == exercise.load)
    }
}
