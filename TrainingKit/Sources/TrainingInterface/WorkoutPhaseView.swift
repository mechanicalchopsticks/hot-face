import SwiftUI
import TrainingDomain

public struct WorkoutPhaseView: View {
    private let workout: WorkoutTimeline
    private let date: Date

    public init(workout: WorkoutTimeline, at date: Date) {
        self.workout = workout
        self.date = date
    }

    public var body: some View {
        let phase = workout.phase(at: date)
        HStack {
            switch phase {
            case .ready: Text("Ready")
            case .preparation: Text("Get ready")
            case .exercise: Text("Exercise")
            case .paused: Text("Paused")
            case .rest: Text("Rest")
            }
            Spacer()
            clock(for: phase, at: date)
        }
        .font(.headline.monospacedDigit())
        .foregroundStyle(phase == .rest ? Color.teal : Color.primary)
    }

    @ViewBuilder
    private func clock(for phase: WorkoutPhase, at now: Date) -> some View {
        switch phase {
        case .preparation: countdown(to: workout.exerciseStart, from: now)
        case .exercise: countdown(to: workout.exerciseEnd, from: now)
        case .rest: countdown(to: workout.restEnd, from: now)
        case .paused: Text(Duration.seconds(workout.pausedSeconds ?? 0).formatted(.time(pattern: .minuteSecond)))
        case .ready: EmptyView()
        }
    }

    @ViewBuilder
    private func countdown(to deadline: Date?, from now: Date) -> some View {
        if let deadline, deadline >= now {
            Text(timerInterval: now...deadline, countsDown: true, showsHours: false)
                .multilineTextAlignment(.trailing)
        }
    }
}
