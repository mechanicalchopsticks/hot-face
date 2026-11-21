import Foundation
import TrainingDomain

public struct SystemWorkoutClock: WorkoutClock {
    public init() {}

    public var now: Date { .now }
}
