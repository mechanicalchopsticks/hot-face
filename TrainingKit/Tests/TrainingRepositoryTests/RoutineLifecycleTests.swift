import Foundation
import SwiftData
import Testing
import TrainingDomain
import TrainingRepositories

private typealias V1 = TrainingSchemaV1

private struct LifecycleClock: WorkoutClock {
    let now = Date(timeIntervalSinceReferenceDate: 1234)
}

struct RoutineLifecycleTests {
    @Test func choosingAmongPreviouslySavedRoutinesArchivesTheOthers() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        func reopen() -> CoordinatedModelStore { CoordinatedModelStore(trainingDirectory: directory) }
        let gym = try #require(reopen().createGym(name: "Gym").activeGymID)
        try reopen().withContext { context in
            for name in ["A", "B"] {
                let exercise = ExercisePrescription(name: "Press", segments: [.repetitions(8)])
                let plan = RoutinePlan(name: name, days: [RoutineDay(name: "Day", exercises: [exercise])])
                context.insert(try V1.Routine(gymID: gym, plan: plan))
            }
            try context.save()
        }
        #expect(try reopen().activeRoutine() == nil)
        let choices = try reopen().editableRoutines(in: gym)
        let chosen = try #require(choices.first { $0.plan.name == "B" })
        try reopen().saveRoutine(chosen)
        #expect(try reopen().activeRoutine()?.id == chosen.id)
        #expect(try reopen().archivedRoutines(in: gym).map(\.plan.name) == ["A"])
    }

    @Test func switchingGymsAndActivatingACopyPreservesOriginalHistory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        func reopen() -> CoordinatedModelStore { CoordinatedModelStore(trainingDirectory: directory) }
        let gymA = try #require(reopen().createGym(name: "A").activeGymID)
        let gymB = try #require(reopen().createGym(name: "B").gyms.first { $0.id != gymA }?.id)
        var curl = ExercisePrescription(name: "Curl", sets: 2, segments: [.repetitions(7), .repetitions(7)])
        curl.supersetID = UUID()
        curl.load = .estimated(.init(amount: 20, unit: .lb, representation: .perImplement, implementCount: 1))
        curl.group = "Arms"
        curl.perSide = true
        curl.variant = "Seated"
        curl.instructions = "Slow"
        curl.restAfterExercise = 80
        let equipment = EquipmentDescription(name: "Dumbbells", kind: .dumbbell, unit: .lb)
        _ = try reopen().saveEquipment(equipment, in: gymA)
        curl.equipmentID = equipment.id
        var row = ExercisePrescription(name: "Row", segments: [.seconds(30)])
        row.supersetID = curl.supersetID
        let day = RoutineDay(name: "Day", exercises: [curl, row])
        var original = ManualRoutine(gymID: gymA)
        original.plan = RoutinePlan(name: "Original", days: [day], defaultSets: 3, restBetweenSets: 60)
        try reopen().saveRoutine(original)
        let saved = try #require(try reopen().activeRoutine())
        let sessionID = UUID()
        func apply(_ action: SessionCommand.Action, session: UUID = sessionID) throws {
            _ = try reopen().apply(SessionCommand(sessionID: session, action: action), clock: LifecycleClock())
        }
        let start = SessionCommand.Action.start(routineID: original.id, gymID: gymA, dayID: day.id, cycleID: nil)
        try apply(start)
        let performance = SetPerformance(asPrescribed: curl)
        try apply(.completeSet(exerciseID: curl.id, number: 1, performance: performance))
        try apply(.rate(exerciseID: curl.id, effort: .easy))
        #expect(throws: RoutineEditorError.openSession(sessionID)) { try reopen().selectGym(gymB) }
        #expect(throws: RoutineEditorError.openSession(sessionID)) { try reopen().archiveRoutine(saved) }
        #expect(throws: RoutineEditorError.openSession(sessionID)) { try reopen().saveRoutine(saved.copy()) }
        #expect(try reopen().selectGym(gymA).activeGymID == gymA)
        #expect(try reopen().activeRoutine()?.id == saved.id)
        try apply(.finish)
        try reopen().withContext { context in
            let balance = try #require(
                context.fetch(FetchDescriptor<V1.Progression>()).first { $0.exerciseID == curl.id })
            balance.balance = 2
            balance.returnRepetitions = 8
            try context.save()
        }

        _ = try reopen().selectGym(gymB)
        #expect(try reopen().activeRoutine() == nil)
        #expect(throws: RoutineEditorError.changedRoutine) { try reopen().saveRoutine(saved) }
        var away = ManualRoutine(gymID: gymB)
        away.plan = RoutinePlan(
            name: "Away",
            days: [RoutineDay(name: "B", exercises: [ExercisePrescription(name: "Walk", segments: [.seconds(60)])])])
        try reopen().saveRoutine(away)
        _ = try reopen().selectGym(gymA)
        #expect(try reopen().activeRoutine() == nil)
        #expect(try reopen().archivedRoutines(in: gymB).map(\.id) == [away.id])
        #expect(throws: SessionCommandError.missingRoutine) { try apply(start, session: UUID()) }
        let archived = try #require(reopen().archivedRoutines(in: gymA).first)
        #expect(archived.id == original.id && archived.plan == original.plan)

        var replacement = ManualRoutine(gymID: gymA)
        replacement.plan = away.plan.copiedForNewRoutine()
        try reopen().saveRoutine(replacement)
        let copy = archived.copy()
        #expect(try reopen().activeRoutine()?.id == replacement.id)
        try reopen().saveRoutine(copy)
        let active = try #require(try reopen().activeRoutine())
        #expect(active.id == copy.id && active.id != archived.id && active.revision == 1)
        #expect(try reopen().editableRoutines(in: gymA).map(\.id) == [copy.id])
        let archives = try reopen().archivedRoutines(in: gymA)
        #expect(Set(archives.map(\.id)) == [original.id, replacement.id])
        #expect(archives.first { $0.id == original.id }?.plan == original.plan)
        #expect(active.plan == copy.plan && active.plan.defaultSets == 3 && active.plan.restBetweenSets == 60)
        let copiedDay = try #require(active.plan.days.first)
        #expect(copiedDay.id != day.id && copiedDay.name == day.name)
        let exercises = copiedDay.exercises
        #expect(exercises.map(\.name) == [curl.name, row.name])
        #expect(Set(exercises.map(\.id)).isDisjoint(with: [curl.id, row.id]))
        #expect(exercises[0].supersetID != nil && exercises[0].supersetID != curl.supersetID)
        #expect(exercises[0].supersetID == exercises[1].supersetID)
        #expect(exercises[0].load == curl.load && exercises[0].equipmentID == equipment.id)
        #expect(exercises[0].segments == curl.segments && exercises[0].variant == curl.variant)
        #expect(exercises[0].instructions == curl.instructions && exercises[0].group == curl.group)
        #expect(exercises[0].perSide && exercises[0].restAfterExercise == 80)
        #expect(exercises[0].sets == 2 && exercises[1].sets == nil)

        try reopen().withContext { context in
            let balances = try context.fetch(FetchDescriptor<V1.Progression>())
            let newIDs = Set(exercises.map(\.id))
            let newBalances = balances.filter { newIDs.contains($0.exerciseID) }
            #expect(newBalances.count == 2 && newBalances.allSatisfy { $0.balance == 0 && $0.returnRepetitions == nil })
            #expect(balances.first { $0.exerciseID == curl.id }?.balance == 2)
            let sessions = try context.fetch(FetchDescriptor<V1.Session>())
            let session = try #require(sessions.first)
            #expect(sessions.count == 1 && session.id == sessionID && session.isPartial && session.finishedAt != nil)
            let snapshot = try session.prescription
            #expect(snapshot.routineID == original.id && snapshot.gymID == gymA && snapshot.day.id == day.id)
            let set = try #require(context.fetch(FetchDescriptor<V1.PerformedSet>()).first)
            #expect(set.sessionID == sessionID && set.exerciseID == curl.id)
            #expect(try set.performance == performance)
            let rating = try #require(context.fetch(FetchDescriptor<V1.Rating>()).first)
            #expect(rating.sessionID == sessionID && rating.exerciseID == curl.id && rating.effort == .easy)
        }
        try reopen().archiveRoutine(active)
        #expect(try reopen().activeRoutine() == nil)
        #expect(try reopen().archivedRoutines(in: gymA).contains { $0.id == copy.id })
    }
}
