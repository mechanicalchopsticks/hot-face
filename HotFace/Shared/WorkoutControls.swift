import ActivityKit
import SwiftUI
import TrainingDomain
import TrainingInterface
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
            WorkoutPhaseView(workout: workout, at: now)
            HStack {
                switch phase {
                case .ready: control("Start", .start, number)
                case .paused: control("Resume", .resume, number)
                case .preparation, .exercise: control("Pause", .pause, number)
                case .rest, .holdPause: EmptyView()
                }
                if phase != .rest {
                    control("Complete set", .complete, number)
                }
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private func control(_ label: LocalizedStringKey, _ action: WorkoutAction, _ number: Int) -> some View {
        if let onAction {
            Button(label) { onAction(action, number) }
        } else {
            Button(intent: WorkoutIntent(action, activityID: activityID, revision: workout.revision, setNumber: number))
            {
                Text(label)
            }
        }
    }
}
