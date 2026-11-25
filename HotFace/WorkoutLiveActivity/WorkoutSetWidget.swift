import ActivityKit
import SwiftUI
import TrainingDomain
import TrainingInterface
import WidgetKit

@main
struct TrainingWidgets: WidgetBundle {
    init() { StorageTrialWidget.listenForCommands() }

    var body: some Widget {
        SessionWidget()
        WorkoutSetWidget()
        StorageTrialWidget()
    }
}

struct WorkoutSetWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SampleSet.self) { context in
            VStack(alignment: .leading) {
                Text(verbatim: context.attributes.exerciseName).font(.headline)
                controls(for: context)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text(verbatim: context.attributes.exerciseName)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    controls(for: context)
                }
            } compactLeading: {
                Image(systemName: "dumbbell")
            } compactTrailing: {
                let date = context.state.presentationDate(isStale: context.isStale, now: .now)
                Text(context.state.workout.currentSet(at: date), format: .number)
            } minimal: {
                Image(systemName: "dumbbell")
            }
        }
    }

    private func controls(for context: ActivityViewContext<SampleSet>) -> some View {
        WorkoutControls(
            activityID: context.activityID,
            workout: context.state.workout,
            presentationDate: context.state.presentationDate(isStale: context.isStale, now: .now)
        )
    }
}

private struct SessionWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SessionActivity.self) { context in
            panel(context).padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) { panel(context) }
            } compactLeading: {
                Image(systemName: "dumbbell")
            } compactTrailing: {
                let now = presentationDate(context)
                let frame = context.state.frame(at: now)
                if let frame, let end = frame.restEnd, end > now {
                    Text(timerInterval: now...end, showsHours: false).frame(width: 43)
                } else if let number = frame?.set?.number {
                    Text(number, format: .number)
                } else {
                    Image(systemName: frame == nil ? "arrow.clockwise" : "checkmark")
                }
            } minimal: {
                Image(systemName: "dumbbell")
            }
        }
    }

    private func presentationDate(_ context: ActivityViewContext<SessionActivity>) -> Date {
        context.isStale ? max(.now, context.state.boundary ?? .distantPast) : .now
    }

    private func panel(_ context: ActivityViewContext<SessionActivity>) -> some View {
        let date = presentationDate(context)
        let frame = context.state.frame(at: date)
        return VStack(alignment: .leading, spacing: 4) {
            if let frame, let set = frame.set {
                let resting = (frame.restEnd ?? .distantPast) > date
                if resting, let end = frame.restEnd {
                    LabeledContent("Rest") { Text(timerInterval: date...end, showsHours: false) }
                    Text("Up next").font(.caption)
                }
                Text(verbatim: set.name).font(.headline).lineLimit(1)
                Text("Set \(set.number) of \(set.count)").font(.caption)
                if !resting {
                    if let timer = frame.timer {
                        WorkoutPhaseView(workout: timer, at: date)
                        HStack {
                            if timer.pausedSeconds != nil {
                                button("Resume", .resume, set, timer.revision, context.activityID)
                            } else if timer.exerciseEnd != nil {
                                button("Pause", .pause, set, timer.revision, context.activityID)
                            } else if date >= (timer.holdAvailableAt ?? .distantPast) {
                                button(
                                    timer.sideNumber == 2 && timer.holdNumber == 1
                                        ? "Start second side" : "Start next hold",
                                    .start, set, timer.revision, context.activityID)
                            }
                            if timer.exerciseStart != nil || timer.pausedSeconds != nil || timer.holdNumber > 1 {
                                button(
                                    set.perSide && timer.sideNumber == 1 ? "Finish side early" : "Finish set early",
                                    .complete, set, timer.revision, context.activityID)
                            }
                        }
                    } else if set.timed {
                        button("Start set", .start, set, context.state.timerStartRevision ?? 0, context.activityID)
                    } else {
                        button("Complete set", .complete, set, nil, context.activityID)
                    }
                }
            } else if frame == nil {
                Label("Updating workout", systemImage: "arrow.clockwise")
            } else {
                Label("All sets completed", systemImage: "checkmark.circle")
            }
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func button(
        _ title: LocalizedStringKey, _ action: WorkoutAction, _ set: SessionActivity.SetInfo,
        _ revision: Int?, _ activityID: String
    ) -> some View {
        Button(intent: SessionControlIntent(action, activityID: activityID, set: set, revision: revision)) {
            Text(title)
        }
    }
}
