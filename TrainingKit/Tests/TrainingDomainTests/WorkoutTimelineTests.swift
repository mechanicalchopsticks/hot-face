import Foundation
import Testing
import TrainingDomain

struct WorkoutTimelineTests {
    @Test func timedSetTransitions() throws {
        let origin = Date(timeIntervalSinceReferenceDate: 1000)
        func at(_ seconds: Double) -> Date { origin.addingTimeInterval(seconds) }

        let ready = WorkoutTimeline()
        let started = try #require(ready.applying(.start, at: origin))
        #expect(started.phase(at: at(2.999)) == .preparation)
        #expect(started.phase(at: at(3)) == .exercise)
        #expect(started.phase(at: at(23)) == .rest)
        #expect(started.phase(at: at(38)) == .ready)
        #expect(started.currentSet(at: at(38)) == 2)
        #expect(started.nextBoundary(after: origin) == at(3))
        #expect(started.nextBoundary(after: at(3)) == at(23))
        #expect(started.nextBoundary(after: at(23)) == at(38))
        #expect(started.nextBoundary(after: at(38)) == nil)

        let paused = try #require(started.applying(.pause, at: at(9)))
        #expect(paused.pausedSeconds == 14)
        #expect(paused.phase(at: at(49)) == .paused)
        #expect(paused.nextBoundary(after: at(49)) == nil)
        let resumed = try #require(paused.applying(.resume, at: at(50)))
        #expect(resumed.phase(at: at(52.999)) == .preparation)
        #expect(resumed.phase(at: at(53)) == .exercise)
        #expect(resumed.exerciseEnd == at(67) && resumed.restEnd == at(82))
        #expect(started.applying(.pause, at: at(1))?.pausedSeconds == 20)

        let manual = try #require(ready.applying(.complete, at: origin))
        #expect(manual.phase(at: origin) == .rest && manual.restEnd == at(15))
        #expect(manual.nextBoundary(after: origin) == at(15))
        #expect(manual.applying(.complete, at: at(1)) == nil)
        #expect(manual.applying(.start, at: at(16))?.setNumber == 2)
        let early = try #require(resumed.applying(.complete, at: at(56)))
        #expect(early.restEnd == at(71) && early.exerciseEnd == nil)
    }
}

private struct FixedClock: WorkoutClock {
    let now: Date
}

private extension WorkoutTimeline {
    func applying(_ action: WorkoutAction, at date: Date) -> Self? {
        applying(
            action, expectedRevision: revision, expectedSet: currentSet(at: date),
            exerciseDuration: 20, restDuration: 15, clock: FixedClock(now: date)
        )
    }
}
