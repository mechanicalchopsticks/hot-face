import ActivityKit
import SwiftUI
import TrainingDomain
import WidgetKit

@main
struct TrainingWidgets: WidgetBundle {
    init() { StorageTrialWidget.listenForCommands() }

    var body: some Widget {
        WorkoutSetWidget()
        SampleWorkoutWidget()
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

private struct SampleWorkoutWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SampleWorkoutActivity.self) { context in
            panel(context)
                .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    panel(context)
                }
            } compactLeading: {
                Image(systemName: "dumbbell")
            } compactTrailing: {
                if let end = context.state.restEnd, !context.isStale, end > .now {
                    timer(until: end).frame(width: 43)
                } else {
                    Text(context.state.setNumber, format: .number)
                }
            } minimal: {
                Image(systemName: "dumbbell")
            }
        }
    }

    private func panel(_ context: ActivityViewContext<SampleWorkoutActivity>) -> some View {
        let state = context.state
        return VStack(alignment: .leading, spacing: 8) {
            if let end = state.restEnd {
                if !context.isStale, end > .now {
                    LabeledContent("Rest") { timer(until: end).multilineTextAlignment(.trailing) }
                        .font(.headline)
                } else {
                    Text("Rest complete").font(.headline)
                }
                Text("Up next").font(.caption)
            }
            Text(verbatim: state.exerciseName).font(.headline)
            Text("Set \(state.setNumber) of \(state.setCount)").font(.subheadline)
            if state.restEnd == nil {
                Button(intent: CompleteSampleWorkoutSet(activityID: context.activityID, setIndex: state.setIndex)) {
                    Label("Complete set", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func timer(until end: Date) -> some View {
        Text(timerInterval: min(.now, end)...end, showsHours: false)
            .monospacedDigit()
    }
}
