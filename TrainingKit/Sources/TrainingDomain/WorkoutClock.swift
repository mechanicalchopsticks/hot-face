import Foundation

public protocol WorkoutClock: Sendable {
    var now: Date { get }
}
