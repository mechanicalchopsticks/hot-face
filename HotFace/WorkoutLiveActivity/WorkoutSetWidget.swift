import ActivityKit
import SwiftUI
import TrainingDomain
import WidgetKit

@main
struct TrainingWidgets: WidgetBundle {
    init() { StorageTrialWidget.listenForCommands() }

    var body: some Widget {
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
