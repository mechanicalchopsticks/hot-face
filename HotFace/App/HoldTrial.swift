import Foundation

enum HoldCue: String, Codable, CaseIterable {
    case firstHold, holdPause, lastHold, lastHoldComplete, lastSetComplete, restComplete

    var soundFile: String { rawValue + ".wav" }
}

struct HoldEvent: Codable, Equatable {
    let cue: HoldCue
    let date: Date
}

struct HoldTrial: Codable {
    let set: Int
    let startsAutomatically: Bool
    let pauseDuration: TimeInterval
    let holdDuration: TimeInterval
    let events: [HoldEvent]

    init(
        set: Int, startsAutomatically: Bool, pauseDuration: TimeInterval,
        holdDuration: TimeInterval, now: Date, lastHoldOnly: Bool = false
    ) {
        self.set = set
        self.startsAutomatically = startsAutomatically
        self.pauseDuration = pauseDuration
        self.holdDuration = holdDuration

        let start = now.addingTimeInterval(3)
        var events: [HoldEvent] = []
        var lastHoldStart = start
        if !lastHoldOnly {
            events.append(HoldEvent(cue: .firstHold, date: start))
            let pause = start.addingTimeInterval(holdDuration)
            events.append(HoldEvent(cue: .holdPause, date: pause))
            lastHoldStart = pause.addingTimeInterval(pauseDuration)
        }
        if startsAutomatically || lastHoldOnly {
            events.append(HoldEvent(cue: .lastHold, date: lastHoldStart))
            let end = lastHoldStart.addingTimeInterval(holdDuration)
            events.append(HoldEvent(cue: set == 1 ? .lastHoldComplete : .lastSetComplete, date: end))
            if set == 1 {
                events.append(HoldEvent(cue: .restComplete, date: end.addingTimeInterval(8)))
            }
        }
        self.events = events
    }

    func continuation(at now: Date) -> Self? {
        guard let last = events.last, now >= last.date else { return nil }
        switch last.cue {
        case .holdPause where now >= last.date.addingTimeInterval(pauseDuration):
            return Self(
                set: set, startsAutomatically: startsAutomatically, pauseDuration: pauseDuration,
                holdDuration: holdDuration, now: now, lastHoldOnly: true)
        case .restComplete:
            return Self(
                set: 2, startsAutomatically: startsAutomatically, pauseDuration: pauseDuration,
                holdDuration: holdDuration, now: now)
        default:
            return nil
        }
    }
}
