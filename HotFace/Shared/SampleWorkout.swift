import ActivityKit
import AppIntents
import Foundation
import Observation
import TrainingDomain

struct SampleWorkout {
    enum Phase: Equatable {
        case ready, set
        case rest(until: Date)
        case summary
    }

    struct Exercise: Identifiable {
        let prescription: ExercisePrescription
        let equipment: EquipmentDescription.Kind
        let setCount: Int

        var id: UUID { prescription.id }

        init(
            _ name: String, equipment: EquipmentDescription.Kind, segment: ExerciseSegment, sets: Int = 4,
            station: String? = nil, instructions: String? = nil, perSide: Bool = false,
            load: Int, unit: ExerciseLoad.Unit = .kg, representation: ExerciseLoad.Representation = .combined,
            implementCount: Int = 1
        ) {
            var prescription = ExercisePrescription(name: name, sets: sets, segments: [segment])
            prescription.station = station
            prescription.instructions = instructions
            prescription.perSide = perSide
            prescription.load = .estimated(
                .init(
                    amount: Decimal(load), unit: unit, representation: representation, implementCount: implementCount))
            self.prescription = prescription
            self.equipment = equipment
            self.setCount = sets
        }
    }

    struct PlannedSet {
        let exercise: Exercise
        let number: Int
    }

    struct CompletedSet: Identifiable {
        let id: Int
        let planned: PlannedSet
        var performance: SetPerformance
    }

    // Day 3 of rutina1. The first exercise uses two sets to failure for the walkthrough.
    static let exercises: [Exercise] = [
        .init(
            "Jalón polea abierto", equipment: .selectorizedMachine, segment: .toFailure, sets: 2, station: "23",
            load: 35),
        .init(
            "Remo T", equipment: .plateLoadedMachine, segment: .repetitions(10), station: "24",
            instructions: "abierto", load: 25, unit: .lb, representation: .totalAdded),
        .init(
            "Remo mancuerna", equipment: .dumbbell, segment: .repetitions(10), perSide: true,
            load: 25, unit: .lb, representation: .perImplement),
        .init("Face pulls", equipment: .selectorizedMachine, segment: .repetitions(15), station: "18", load: 15),
        .init(
            "Curl martillo", equipment: .dumbbell, segment: .repetitions(10), load: 15, unit: .lb,
            representation: .perImplement, implementCount: 2),
        .init("Curl barra", equipment: .fixedBar, segment: .repetitions(12), load: 15),
    ]

    private static let planned = exercises.flatMap { exercise in
        (1...exercise.setCount).map { PlannedSet(exercise: exercise, number: $0) }
    }

    private(set) var phase = Phase.ready
    private(set) var completed: [CompletedSet] = []

    var currentSet: PlannedSet? {
        guard Self.planned.indices.contains(completed.count) else { return nil }
        return Self.planned[completed.count]
    }

    var continuesExercise: Bool { currentSet?.number != 1 }

    var isResting: Bool {
        if case .rest = phase { return true }
        return false
    }

    mutating func start() { phase = .set }
    mutating func finish() { phase = .summary }

    mutating func completeSet(at date: Date) {
        guard phase == .set, let currentSet else { return }
        completed.append(
            .init(
                id: completed.count, planned: currentSet,
                performance: SetPerformance(asPrescribed: currentSet.exercise.prescription)))
        if self.currentSet != nil {
            let rest: TimeInterval = continuesExercise ? 105 : 135
            phase = .rest(until: date.addingTimeInterval(rest))
        } else {
            finish()
        }
    }

    mutating func correct(_ record: CompletedSet, with performance: SetPerformance) {
        guard isResting, completed.last?.id == record.id else { return }
        completed[record.id].performance = performance
    }

    mutating func advance() {
        guard isResting else { return }
        phase = .set
    }
}

struct SampleWorkoutActivity: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let setIndex: Int
        let exerciseName: String
        let setNumber: Int
        let setCount: Int
        let restEnd: Date?
    }
}

struct CompleteSampleWorkoutSet: LiveActivityIntent {
    static var title: LocalizedStringResource = "Complete set"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Activity") var activityID: String
    @Parameter(title: "Set") var setIndex: Int

    init() {}

    init(activityID: String, setIndex: Int) {
        self.activityID = activityID
        self.setIndex = setIndex
    }

    func perform() async throws -> some IntentResult {
        try await SampleWorkoutController.shared.completeSet(activityID: activityID, setIndex: setIndex)
        return .result()
    }
}

private enum SampleWorkoutActionError: LocalizedError {
    case setUnavailable

    var errorDescription: String? {
        String(localized: "Open HotFace to check the current set.")
    }
}

// LiveActivityIntent runs in the app process and uses the same in-memory sample as Train.
@MainActor @Observable
final class SampleWorkoutController {
    static let shared = SampleWorkoutController()

    private(set) var session = SampleWorkout()
    private(set) var liveActivityUnavailable = false
    @ObservationIgnored private var activity: Activity<SampleWorkoutActivity>?
    @ObservationIgnored private var activityUpdate: Task<Void, Never>?

    private init() {}

    func start(showsLiveActivity: Bool) {
        guard session.phase == .ready else { return }
        session.start()
        let oldActivities = Activity<SampleWorkoutActivity>.activities
        if !oldActivities.isEmpty {
            Task {
                for oldActivity in oldActivities {
                    await oldActivity.end(nil, dismissalPolicy: .immediate)
                }
            }
        }
        guard showsLiveActivity, let state = activityState else { return }
        do {
            activity = try Activity.request(
                attributes: SampleWorkoutActivity(), content: content(for: state), pushType: nil)
        } catch {
            liveActivityUnavailable = true
        }
    }

    func completeSet() {
        session.completeSet(at: .now)
        publishActivity()
    }

    func completeSet(activityID: String, setIndex: Int) async throws {
        guard activity?.id == activityID, session.phase == .set, session.completed.count == setIndex else {
            throw SampleWorkoutActionError.setUnavailable
        }
        completeSet()
        await activityUpdate?.value
    }

    func correct(_ record: SampleWorkout.CompletedSet, with performance: SetPerformance) {
        session.correct(record, with: performance)
    }

    func advance() {
        session.advance()
        publishActivity()
    }

    func finish() {
        session.finish()
        publishActivity()
    }

    func close() {
        session = SampleWorkout()
        liveActivityUnavailable = false
        publishActivity()
    }

    private var activityState: SampleWorkoutActivity.ContentState? {
        guard let current = session.currentSet, session.phase != .ready, session.phase != .summary else { return nil }
        let restEnd: Date? = if case .rest(let end) = session.phase { end } else { nil }
        return .init(
            setIndex: session.completed.count, exerciseName: current.exercise.prescription.name,
            setNumber: current.number, setCount: current.exercise.setCount, restEnd: restEnd)
    }

    private func content(for state: SampleWorkoutActivity.ContentState) -> ActivityContent<
        SampleWorkoutActivity.ContentState
    > {
        .init(state: state, staleDate: state.restEnd)
    }

    private func publishActivity() {
        guard let activity else { return }
        let snapshot = activityState.map(content(for:))
        if snapshot == nil { self.activity = nil }
        let previous = activityUpdate
        activityUpdate = Task {
            await previous?.value
            if let snapshot {
                await activity.update(snapshot)
            } else {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
