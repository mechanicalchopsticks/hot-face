import ActivityKit
import AlarmKit
import AppIntents
import SwiftUI

struct WorkoutIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Control sample set"
    static var isDiscoverable: Bool = false
    @Parameter(title: "Activity") var activityID: String
    @Parameter(title: "Action") var command: String
    @Parameter(title: "Revision") var revision: Int
    @Parameter(title: "Set") var setNumber: Int

    init() {}

    init(_ action: WorkoutAction, activityID: String, revision: Int, setNumber: Int) {
        self.activityID = activityID
        self.command = action.rawValue
        self.revision = revision
        self.setNumber = setNumber
    }

    func perform() async throws -> some IntentResult {
        if let action = WorkoutAction(rawValue: command) {
            let preparation = try await WorkoutController.shared.apply(action, id: activityID, revision: revision, setNumber: setNumber)
            // Deliver the exercise snapshot before this Lock Screen interaction finishes.
            await preparation?.value
        }
        return .result()
    }
}

private struct WorkoutAlarmMetadata: AlarmMetadata {}

enum ProbeError: LocalizedError {
    case alarmPermission, liveActivityPermission, actionInProgress

    var errorDescription: String? {
        switch self {
        case .alarmPermission: String(localized: "Allow alarms in Settings to run the test.")
        case .liveActivityPermission: String(localized: "Enable Live Activities in Settings to start the test.")
        case .actionInProgress: String(localized: "Another action is in progress. Try again.")
        }
    }
}

// LiveActivityIntent runs in the app process, including actions from the Lock Screen.
@MainActor
final class WorkoutController {
    static let shared = WorkoutController()
    private let manager = AlarmManager.shared
    private var busy = false
    private var phaseUpdates: Task<Void, Never>?

    func begin() async throws -> Activity<SampleSet> {
        guard !busy else { throw ProbeError.actionInProgress }
        busy = true
        defer { busy = false }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { throw ProbeError.liveActivityPermission }
        let permission = try await manager.requestAuthorization()
        guard permission == .authorized else { throw ProbeError.alarmPermission }
        if let activity = Activity<SampleSet>.activities.first { return activity }
        // This prototype owns all of its alarms. Clear any left by a dismissed activity.
        try cancel(try manager.alarms.map(\.id))
        return try Activity.request(
            attributes: SampleSet(exerciseName: String(localized: "Sample squat")),
            content: ActivityContent(state: .init(setNumber: 1), staleDate: nil),
            pushType: nil
        )
    }

    func finish(_ activity: Activity<SampleSet>) async throws {
        guard !busy else { throw ProbeError.actionInProgress }
        busy = true
        defer { busy = false }
        try cancel(try manager.alarms.map(\.id))
        phaseUpdates?.cancel()
        await activity.end(nil, dismissalPolicy: .immediate)
    }

    @discardableResult
    func apply(_ action: WorkoutAction, id: String, revision: Int, setNumber: Int) async throws -> Task<Void, Never>? {
        guard !busy else { throw ProbeError.actionInProgress }
        guard let activity = Activity<SampleSet>.activities.first(where: { $0.id == id }) else { return nil }
        let now = Date()
        let previous = activity.content.state
        guard previous.workout.revision == revision, previous.workout.currentSet(at: now) == setNumber,
              let next = previous.workout.applying(action, at: now) else { return nil }
        guard manager.authorizationState == .authorized else { throw ProbeError.alarmPermission }
        busy = true
        defer { busy = false }

        var alarms: [UUID] = []
        do {
            if let end = next.exerciseEnd {
                alarms.append(try await schedule(at: end, title: "Set complete · Rest started"))
            }
            if let end = next.restEnd {
                alarms.append(try await schedule(at: end, title: "Rest complete · Next set ready"))
            }
            try cancel(previous.alarmIDs ?? [])
        } catch {
            try cancel(alarms)
            throw error
        }

        let content = SampleSet.ContentState(setNumber: next.setNumber, timeline: next, alarmIDs: alarms)
        phaseUpdates?.cancel()
        let boundary = await publish(content, for: activity)
        let update = scheduleNextUpdate(for: activity, content: content, at: boundary)
        return boundary == next.exerciseStart ? update : nil
    }

    func restorePresentation(for activity: Activity<SampleSet>) {
        guard !busy else { return }
        let content = activity.content.state
        phaseUpdates?.cancel()
        scheduleNextUpdate(for: activity, content: content, at: .now)
    }

    @discardableResult
    private func scheduleNextUpdate(for activity: Activity<SampleSet>, content: SampleSet.ContentState, at boundary: Date?) -> Task<Void, Never>? {
        guard let boundary else {
            phaseUpdates = nil
            return nil
        }
        let update = Task { @MainActor in
            do {
                while boundary > .now {
                    try await Task.sleep(for: .seconds(max(0, boundary.timeIntervalSinceNow)))
                }
            } catch { return }
            // All accepted actions replace this task. ActivityKit's readable snapshot may
            // still reflect the previous revision immediately after a pause and resume.
            guard !Task.isCancelled, activity.activityState == .active || activity.activityState == .stale else { return }
            let next = await publish(content, for: activity)
            guard !Task.isCancelled else { return }
            scheduleNextUpdate(for: activity, content: content, at: next)
        }
        phaseUpdates = update
        return update
    }

    private func publish(_ content: SampleSet.ContentState, for activity: Activity<SampleSet>) async -> Date? {
        let now = Date.now
        var snapshot = content
        snapshot.nextPhaseDate = content.workout.nextBoundary(after: now)
        await activity.update(ActivityContent(state: snapshot, staleDate: snapshot.nextPhaseDate), timestamp: now)
        return snapshot.nextPhaseDate
    }

    func cancel(_ ids: [UUID]) throws {
        guard !ids.isEmpty else { return }
        for alarm in try manager.alarms where ids.contains(alarm.id) {
            try manager.cancel(id: alarm.id)
        }
    }

    func schedule(at date: Date, title: LocalizedStringResource, id: UUID = UUID(),
                  sound: AlertConfiguration.AlertSound = .default) async throws -> UUID {
        let alert: AlarmPresentation.Alert
        if #available(iOS 26.1, *) {
            alert = AlarmPresentation.Alert(title: title)
        } else {
            alert = AlarmPresentation.Alert(title: title, stopButton: AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.fill"))
        }
        let attributes = AlarmAttributes<WorkoutAlarmMetadata>(presentation: .init(alert: alert), tintColor: .orange)
        let alarm = try await manager.schedule(id: id, configuration: .alarm(schedule: .fixed(date), attributes: attributes, sound: sound))
        return alarm.id
    }
}
