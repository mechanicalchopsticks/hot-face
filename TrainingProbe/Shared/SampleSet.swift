import ActivityKit
import Foundation

struct SampleSet: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let setNumber: Int
        var timeline: WorkoutTimeline?
        var alarmIDs: [UUID]?
        var nextPhaseDate: Date?

        func presentationDate(isStale: Bool, now: Date) -> Date {
            guard isStale, let nextPhaseDate else { return now }
            // WidgetKit can prepare the stale presentation before the boundary occurs.
            return max(now, nextPhaseDate)
        }

        var workout: WorkoutTimeline { timeline ?? WorkoutTimeline(setNumber: setNumber) }
    }

    let exerciseName: String
}
