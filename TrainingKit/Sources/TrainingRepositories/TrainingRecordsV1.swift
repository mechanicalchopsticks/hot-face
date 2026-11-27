import Foundation
import SwiftData
import TrainingDomain

extension TrainingSchemaV1 {
    @Model
    public final class PerformedSet {
        @Attribute(.unique) public private(set) var id: UUID
        public private(set) var sessionID: UUID
        public private(set) var exerciseID: UUID
        public private(set) var number: Int
        public private(set) var performedAt: Date
        private var performanceData: Data

        public init(
            sessionID: UUID, exerciseID: UUID, number: Int, performedAt: Date,
            performance: SetPerformance
        ) throws {
            self.id = UUID()
            self.sessionID = sessionID
            self.exerciseID = exerciseID
            self.number = number
            self.performedAt = performedAt
            self.performanceData = try JSONEncoder().encode(performance)
        }

        public var performance: SetPerformance {
            get throws { try JSONDecoder().decode(SetPerformance.self, from: performanceData) }
        }

        public func correct(to performance: SetPerformance) throws {
            performanceData = try JSONEncoder().encode(performance)
        }
    }

    @Model
    public final class Rating {
        @Attribute(.unique) public private(set) var id: UUID
        public private(set) var sessionID: UUID
        public private(set) var exerciseID: UUID
        public var effort: Effort
        public var date: Date

        public init(sessionID: UUID, exerciseID: UUID, effort: Effort, date: Date) {
            self.id = UUID()
            self.sessionID = sessionID
            self.exerciseID = exerciseID
            self.effort = effort
            self.date = date
        }
    }

    @Model
    public final class Progression {
        @Attribute(.unique) public private(set) var exerciseID: UUID
        public var balance: Int
        public var returnRepetitions: Int?

        public init(exerciseID: UUID) {
            self.exerciseID = exerciseID
            self.balance = 0
        }
    }

    @Model
    public final class PrescriptionChange {
        @Attribute(.unique) public private(set) var id: UUID
        public private(set) var routineID: UUID
        public private(set) var date: Date
        public private(set) var origin: String
        private var previousData: Data
        private var updatedData: Data

        public init(
            routineID: UUID, date: Date, origin: String,
            previous: ExercisePrescription, updated: ExercisePrescription
        ) throws {
            self.id = UUID()
            self.routineID = routineID
            self.date = date
            self.origin = origin
            self.previousData = try JSONEncoder().encode(previous)
            self.updatedData = try JSONEncoder().encode(updated)
        }

        public var previous: ExercisePrescription {
            get throws { try JSONDecoder().decode(ExercisePrescription.self, from: previousData) }
        }

        public var updated: ExercisePrescription {
            get throws { try JSONDecoder().decode(ExercisePrescription.self, from: updatedData) }
        }
    }

    @Model
    public final class Note {
        @Attribute(.unique) public private(set) var id: UUID
        public private(set) var date: Date
        public var exerciseID: UUID?
        public var sessionID: UUID?
        public var text: String

        public init(id: UUID = UUID(), date: Date, text: String, exerciseID: UUID? = nil, sessionID: UUID? = nil) {
            self.id = id
            self.date = date
            self.text = text
            self.exerciseID = exerciseID
            self.sessionID = sessionID
        }
    }
}
