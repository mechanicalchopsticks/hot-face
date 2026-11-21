import ActivityKit
import SwiftUI
import WidgetKit

struct WorkoutControls: View {
    let activityID: String
    let workout: WorkoutTimeline
    var presentationDate: Date?
    // The app reports action errors inline. Widget buttons dispatch the same action as an intent.
    var onAction: ((WorkoutAction, Int) -> Void)?

    var body: some View {
        if let presentationDate {
            controls(at: presentationDate)
        } else {
            TimelineView(.periodic(from: .now, by: 1)) { tick in
                controls(at: tick.date)
            }
        }
    }

    private func controls(at now: Date) -> some View {
        let phase = workout.phase(at: now)
        let number = workout.currentSet(at: now)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Set \(number)").font(.caption)
            HStack {
                switch phase {
                case .ready: Text("Ready")
                case .preparation: Text("Get ready")
                case .exercise: Text("Exercise")
                case .paused: Text("Paused")
                case .rest: Text("Rest")
                }
                Spacer()
                clock(for: phase, at: now)
            }
            .font(.headline.monospacedDigit())
            .foregroundStyle(phase == .rest ? Color.teal : Color.primary)
            HStack {
                switch phase {
                case .ready: control("Start", .start, number)
                case .paused: control("Resume", .resume, number)
                case .preparation, .exercise: control("Pause", .pause, number)
                case .rest: EmptyView()
                }
                if phase != .rest {
                    control("Complete set", .complete, number)
                }
            }
            .buttonStyle(.bordered)
        }
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

    @ViewBuilder
    private func control(_ label: LocalizedStringKey, _ action: WorkoutAction, _ number: Int) -> some View {
        if let onAction {
            Button(label) { onAction(action, number) }
        } else {
            Button(intent: WorkoutIntent(action, activityID: activityID, revision: workout.revision, setNumber: number)) {
                Text(label)
            }
        }
    }
}
