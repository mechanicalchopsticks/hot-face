import ActivityKit
import AlarmKit
import SwiftUI

@main
struct TrainingProbe: App {
    @UIApplicationDelegateAdaptor(HoldAudioDelegate.self) private var audioDelegate

    var body: some Scene {
        WindowGroup { ProbeView().task { await StorageTrialRunner.runIfRequested() } }
    }
}

private struct ProbeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var activity: Activity<SampleSet>?
    @AppStorage("holdTrial") private var savedHoldTrial = Data()
    @State private var workout = WorkoutTimeline()
    @State private var notice: String?
    @State private var performingAction = false
    @State private var alarmPermission = AlarmManager.shared.authorizationState
    @State private var liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled

    var body: some View {
        Form {
            Section("Sample squat") {
                Text("3 s preparation · 20 s exercise · 15 s rest")
                if let activity {
                    WorkoutControls(activityID: activity.id, workout: workout) { action, number in
                        let revision = workout.revision
                        run {
                            try await WorkoutController.shared.apply(action, id: activity.id, revision: revision, setNumber: number)
                        }
                    }
                    Button("End activity") { run { try await WorkoutController.shared.finish(activity) } }
                } else {
                    Button("Start activity") { run { _ = try await WorkoutController.shared.begin() } }
                        .disabled(!savedHoldTrial.isEmpty)
                }
                if let notice { Text(notice) }
            }
            .disabled(performingAction)
            HoldAudioProbe()
                .disabled(activity != nil || performingAction)
            Section("Permissions") {
                LabeledContent("Live Activities") { Text(liveActivitiesEnabled ? "Enabled" : "Disabled") }
                LabeledContent("Alarms") {
                    switch alarmPermission {
                    case .authorized: Text("Allowed")
                    case .denied: Text("Denied")
                    case .notDetermined: Text("Not requested")
                    @unknown default: Text("Unknown")
                    }
                }
            }
        }
        .onChange(of: scenePhase, initial: true) {
            if scenePhase == .active {
                refresh()
                if let activity { WorkoutController.shared.restorePresentation(for: activity) }
            }
        }
        .task(id: activity?.id) {
            guard let activity else { return }
            for await content in activity.contentUpdates {
                guard !Task.isCancelled else { return }
                workout = content.state.workout
            }
        }
    }

    private func refresh() {
        activity = Activity<SampleSet>.activities.first
        workout = activity?.content.state.workout ?? WorkoutTimeline()
        alarmPermission = AlarmManager.shared.authorizationState
        liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
    }

    private func run(_ operation: @escaping @MainActor () async throws -> Void) {
        guard !performingAction else { return }
        performingAction = true
        notice = nil
        Task { @MainActor in
            do { try await operation() }
            catch { notice = error.localizedDescription }
            refresh()
            performingAction = false
        }
    }
}
