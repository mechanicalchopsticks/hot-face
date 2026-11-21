import Foundation

@main
struct WorkoutTimelineChecks {
    static func main() throws {
        let origin = Date(timeIntervalSinceReferenceDate: 1000)
        func at(_ seconds: Double) -> Date { origin.addingTimeInterval(seconds) }

        let ready = WorkoutTimeline()
        let started = try require(ready.applying(.start, at: origin))
        precondition(started.phase(at: at(2.999)) == .preparation)
        precondition(started.phase(at: at(3)) == .exercise)
        precondition(started.phase(at: at(23)) == .rest)
        precondition(started.phase(at: at(38)) == .ready)
        precondition(started.currentSet(at: at(38)) == 2)
        precondition(started.nextBoundary(after: origin) == at(3))
        precondition(started.nextBoundary(after: at(3)) == at(23))
        precondition(started.nextBoundary(after: at(23)) == at(38))
        precondition(started.nextBoundary(after: at(38)) == nil)

        let paused = try require(started.applying(.pause, at: at(9)))
        precondition(paused.pausedSeconds == 14)
        precondition(paused.phase(at: at(49)) == .paused)
        precondition(paused.nextBoundary(after: at(49)) == nil)
        let resumed = try require(paused.applying(.resume, at: at(50)))
        precondition(resumed.phase(at: at(52.999)) == .preparation)
        precondition(resumed.phase(at: at(53)) == .exercise)
        precondition(resumed.exerciseEnd == at(67) && resumed.restEnd == at(82))
        precondition(started.applying(.pause, at: at(1))?.pausedSeconds == 20)

        let manual = try require(ready.applying(.complete, at: origin))
        precondition(manual.phase(at: origin) == .rest && manual.restEnd == at(15))
        precondition(manual.nextBoundary(after: origin) == at(15))
        precondition(manual.applying(.complete, at: at(1)) == nil)
        precondition(manual.applying(.start, at: at(16))?.setNumber == 2)
        let early = try require(resumed.applying(.complete, at: at(56)))
        precondition(early.restEnd == at(71) && early.exerciseEnd == nil)
        print("Workout timeline checks passed.")
    }

    private static func require(_ value: WorkoutTimeline?) throws -> WorkoutTimeline {
        guard let value else { throw CheckError.unexpectedTransition }
        return value
    }

    private enum CheckError: Error { case unexpectedTransition }
}
