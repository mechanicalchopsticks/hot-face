import Foundation
import SwiftData
import Testing
import TrainingDomain
import TrainingRepositories

private typealias V1 = TrainingSchemaV1

struct SessionSnapshotTests {
    private func withTemporaryStore(_ test: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try test(directory)
    }

    @Test func historicalSessionSurvivesRoutineAndEquipmentEdits() throws {
        try withTemporaryStore { directory in
            func reopen() -> CoordinatedModelStore { CoordinatedModelStore(trainingDirectory: directory) }

            let equipment = EquipmentDescription(name: "Barra olímpica", kind: .barbell, unit: .kg)
            let weight = ExerciseLoad(amount: 12.5, unit: .kg, representation: .perSide, implementCount: 2)
            var first = ExercisePrescription(
                name: "Curl 21", sets: 4, segments: Array(repeating: .repetitions(7), count: 3))
            first.load = .estimated(weight)
            first.equipmentID = equipment.id
            first.station = "MAQ 7"
            first.instructions = "Último tramo lento"
            let second = ExercisePrescription(name: "Plancha", sets: 3, segments: [.seconds(40)])
            let day = RoutineDay(name: "Día A", exercises: [first, second])
            let otherDay = RoutineDay(name: "Día B", exercises: [])
            let original = RoutinePlan(name: "Fuerza", days: [otherDay, day])
            let actual = SetPerformance(
                segments: [.repetitions(7), .repetitions(7), .repetitions(5)],
                load: weight, isPartial: true)
            let start = Date(timeIntervalSince1970: 1000)
            let end = start.addingTimeInterval(300)

            let (gymID, routineID, sessionID) = try reopen().withContext { context in
                let gym = try V1.Gym(name: "Gimnasio A", equipment: [equipment])
                let routine = try V1.Routine(gymID: gym.id, plan: original)
                let cycle = V1.Cycle(routineID: routine.id, orderedDayIDs: [day.id, otherDay.id])
                let session = try V1.Session(routine: routine, gym: gym, dayID: day.id, cycle: cycle, startedAt: start)
                context.insert(gym)
                context.insert(routine)
                context.insert(cycle)
                context.insert(session)
                try context.save()
                return (gym.id, routine.id, session.id)
            }

            try reopen().withContext { context in
                let session = try #require(context.fetch(FetchDescriptor<V1.Session>()).first)
                #expect(session.finishedAt == nil)
                context.insert(
                    try V1.PerformedSet(
                        sessionID: session.id, exerciseID: first.id, number: 1,
                        performedAt: end, performance: actual))
                context.insert(V1.Rating(sessionID: session.id, exerciseID: first.id, effort: .hard, date: end))
                session.skippedExerciseIDs = [second.id]
                session.finish(at: end, partial: true)
                try context.save()
            }

            try reopen().withContext { context in
                let gym = try #require(context.fetch(FetchDescriptor<V1.Gym>()).first)
                let routine = try #require(context.fetch(FetchDescriptor<V1.Routine>()).first)
                #expect(try routine.plan == original)
                var edited = try routine.plan
                edited.name = "Nueva rutina"
                edited.days[1].exercises = [second]
                edited.restBetweenSets = 30
                try routine.replacePlan(edited)
                routine.isArchived = true
                gym.name = "Nuevo nombre"
                try gym.replaceEquipment([])
                try context.save()
            }

            try reopen().withContext { context in
                let routine = try #require(context.fetch(FetchDescriptor<V1.Routine>()).first)
                #expect(routine.revision == 2 && routine.isArchived)
                #expect(try routine.plan.days[1].exercises == [second])
                let session = try #require(context.fetch(FetchDescriptor<V1.Session>()).first)
                #expect(session.id == sessionID && session.startedAt == start)
                let cycle = try #require(context.fetch(FetchDescriptor<V1.Cycle>()).first)
                #expect(cycle.id == session.cycleID && cycle.routineID == routineID)
                #expect(cycle.orderedDayIDs == [day.id, otherDay.id])
                #expect(session.isPartial && session.finishedAt == end)
                #expect(session.skippedExerciseIDs == [second.id])
                let snapshot = try session.prescription
                #expect(snapshot.routineID == routineID && snapshot.routineRevision == 1)
                #expect(snapshot.routineName == original.name && snapshot.day == day)
                #expect(snapshot.gymID == gymID && snapshot.gymName == "Gimnasio A")
                #expect(snapshot.equipment == [equipment])
                #expect(snapshot.restBetweenSets == original.restBetweenSets)
                #expect(snapshot.restBetweenExercises == original.restBetweenExercises)
                let set = try #require(context.fetch(FetchDescriptor<V1.PerformedSet>()).first)
                #expect(set.sessionID == sessionID && set.exerciseID == first.id)
                #expect(set.number == 1 && set.performedAt == end)
                #expect(try set.performance == actual)
                let rating = try #require(context.fetch(FetchDescriptor<V1.Rating>()).first)
                #expect(rating.sessionID == sessionID && rating.exerciseID == first.id && rating.effort == .hard)
            }
        }
    }

    @Test func reopensLegacyChangeAndResolvesEachEquipmentInItsGym() throws {
        // Frozen before one-sided editor changes. The saved session lasted 75 seconds.
        let fixture = try #require(
            Bundle.module.url(forResource: "before-one-sided-changes", withExtension: "store", subdirectory: "Fixtures")
        )
        try withTemporaryStore { directory in
            try FileManager.default.copyItem(at: fixture, to: directory.appendingPathComponent("training.store"))
            func reopen() -> CoordinatedModelStore { CoordinatedModelStore(trainingDirectory: directory) }
            let change = try #require(try reopen().prescriptionChanges().first)
            #expect(change.previous?.name == "Curl" && change.updated?.name == "Curl")
            #expect(change.previousEquipment == .generic(.dumbbell))
            #expect(change.updatedEquipment == .named("West rack"))
            let session = try #require(try reopen().workoutHistory().sessions.first)
            #expect(session.duration == 75)
            #expect(session.exercises.last?.prescription.bandColor == .red)
            let rack = try #require(change.updated?.equipmentID)
            _ = try reopen().deleteEquipment(rack, in: session.snapshot.gymID)
            let reopenedChange = try #require(try reopen().prescriptionChanges().first)
            #expect(reopenedChange.previousEquipment == .generic(.dumbbell))
            #expect(reopenedChange.updatedEquipment == .unavailable(rack))
        }
    }

    @Test func reloadsPrescriptionChangesProgressionAndNotes() throws {
        try withTemporaryStore { directory in
            let previous = ExercisePrescription(name: "Remo", sets: 3, segments: [.repetitions(10)])
            var updated = previous
            updated.segments = [.repetitions(12)]
            let routineID = UUID()
            let date = Date(timeIntervalSince1970: 1300)
            try CoordinatedModelStore(trainingDirectory: directory).withContext { context in
                let change = try V1.PrescriptionChange(
                    routineID: routineID, date: date, origin: "suggestion",
                    previous: previous, updated: updated)
                let progression = V1.Progression(exerciseID: updated.id)
                progression.returnRepetitions = 10
                context.insert(change)
                context.insert(progression)
                context.insert(V1.Note(date: date, text: "Más control", exerciseID: updated.id))
                try context.save()
            }
            try CoordinatedModelStore(trainingDirectory: directory).withContext { context in
                let change = try #require(context.fetch(FetchDescriptor<V1.PrescriptionChange>()).first)
                #expect(change.routineID == routineID && change.date == date && change.origin == "suggestion")
                #expect(try change.previous == previous)
                #expect(try change.updated == updated)
                let progression = try #require(context.fetch(FetchDescriptor<V1.Progression>()).first)
                #expect(progression.exerciseID == updated.id && progression.returnRepetitions == 10)
                #expect(progression.balance == 0)
                let note = try #require(context.fetch(FetchDescriptor<V1.Note>()).first)
                #expect(note.exerciseID == updated.id && note.date == date && note.text == "Más control")
            }
        }
    }
}
