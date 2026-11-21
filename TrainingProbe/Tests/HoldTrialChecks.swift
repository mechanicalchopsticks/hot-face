import Foundation

@main
struct HoldTrialChecks {
    static func main() throws {
        let start = Date(timeIntervalSinceReferenceDate: 1000)
        func at(_ offset: TimeInterval) -> Date { start.addingTimeInterval(offset) }

        let first = HoldTrial(set: 1, startsAutomatically: true, pauseDuration: 3, holdDuration: 6, now: start)
        precondition(first.events.map(\.cue) == [.firstHold, .holdPause, .lastHold, .lastHoldComplete, .restComplete])
        precondition(first.events.map(\.date) == [3, 9, 12, 18, 26].map(at))
        precondition(first.continuation(at: at(25.99)) == nil)
        let second = first.continuation(at: at(30))!
        precondition(second.set == 2 && second.events.last == HoldEvent(cue: .lastSetComplete, date: at(48)))
        precondition(second.continuation(at: at(100)) == nil)

        let manual = HoldTrial(set: 1, startsAutomatically: false, pauseDuration: 5, holdDuration: 90, now: start)
        precondition(manual.events.map(\.date) == [3, 93].map(at))
        precondition(manual.continuation(at: at(97.99)) == nil)
        let recovered = try JSONDecoder().decode(HoldTrial.self, from: JSONEncoder().encode(manual))
        let lastHold = recovered.continuation(at: at(120))!
        precondition(lastHold.events.map(\.cue) == [.lastHold, .lastHoldComplete, .restComplete])
        precondition(lastHold.events.map(\.date) == [123, 213, 221].map(at))
        precondition(lastHold.continuation(at: at(221))?.events.map(\.cue) == [.firstHold, .holdPause])
        print("Hold trial checks passed.")
    }
}
