import ActivityKit
import AppIntents
import Foundation
import TrainingAdapters
import TrainingDomain
import TrainingRepositories
import UserNotifications

struct SessionActivity: ActivityAttributes {
    let sessionID: UUID

    typealias SetInfo = WorkoutActivityState.SetInfo
    typealias ContentState = WorkoutActivityState
}

enum SessionActivityError: LocalizedError {
    case unavailable, stale
    var errorDescription: String? {
        switch self {
        case .unavailable: String(localized: "Lock Screen controls are unavailable.")
        case .stale: String(localized: "Open HotFace to check the current set.")
        }
    }
}

struct SessionControlIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Control workout"
    static var isDiscoverable: Bool = false
    @Parameter(title: "Activity") var activityID: String
    @Parameter(title: "Exercise") var exerciseID: String
    @Parameter(title: "Set") var number: Int
    @Parameter(title: "Revision") var revision: Int?
    @Parameter(title: "Action") var action: String

    init() {}

    init(_ action: WorkoutAction, activityID: String, set: SessionActivity.SetInfo, revision: Int?) {
        self.action = action.rawValue
        self.activityID = activityID
        exerciseID = set.id.uuidString
        number = set.number
        self.revision = revision
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard ActivityAuthorizationInfo().areActivitiesEnabled,
            let activity = Activity<SessionActivity>.activities.first(where: { $0.id == activityID }),
            activity.activityState == .active || activity.activityState == .stale,
            let id = UUID(uuidString: exerciseID), let action = WorkoutAction(rawValue: action)
        else { throw SessionActivityError.stale }
        let displayedFrame = activity.content.state.frame(at: .now)
        let controller = SessionActivityController.shared
        do {
            let store = try TrainingStorage.openStore()
            let command: SessionCommand.Action
            if let revision {
                command = .controlTimer(exerciseID: id, number: number, expectedRevision: revision, action: action)
            } else {
                guard action == .complete else { throw SessionActivityError.stale }
                command = .logCurrentSet(exerciseID: id, number: number)
            }
            guard
                try store.apply(
                    .init(sessionID: activity.attributes.sessionID, action: command),
                    clock: SystemWorkoutClock()) == .applied
            else { throw SessionActivityError.stale }
        } catch {
            await controller.refresh().value
            throw SessionActivityError.stale
        }
        if action == .complete, let displayedFrame, let set = displayedFrame.set {
            let kind: WorkoutTimingCue.Kind =
                set.perSide && displayedFrame.timer?.sideNumber == 1
                ? .sideCompleted : (set.number == set.count ? .lastSetCompleted : .setCompleted)
            await controller.signal(kind)
        }
        await controller.refresh().value
        // A locked intent can be suspended as soon as it returns. Publish the end of
        // the three-second preparation before handing control back to iOS.
        if action == .start || action == .resume,
            let workout = try? TrainingStorage.openStore().openWorkout(), workout.id == activity.attributes.sessionID,
            let start = workout.timer?.exerciseStart, start > .now, start.timeIntervalSinceNow <= 3
        {
            try? await Task.sleep(for: .seconds(max(0, start.timeIntervalSinceNow)))
            await controller.refresh().value
        }
        NotificationCenter.default.post(name: .workoutControlPerformed, object: nil)
        return .result()
    }
}

extension Notification.Name {
    static let workoutControlPerformed = Self("workoutControlPerformed")
}

extension WorkoutTimingCue.Kind {
    var notificationTitle: LocalizedStringResource {
        switch self {
        case .holdStarted: "Hold started"
        case .lastHoldStarted: "Last hold"
        case .holdEnded: "Pause between holds"
        case .sideCompleted: "Side complete"
        case .setCompleted: "Set complete"
        case .lastSetCompleted: "Last set complete"
        case .restCompleted: "Rest complete · Next set ready"
        }
    }

    var soundFile: String {
        switch self {
        case .holdStarted: "firstHold.wav"
        case .lastHoldStarted: "lastHold.wav"
        case .holdEnded: "holdPause.wav"
        case .sideCompleted: "sideComplete.wav"
        case .setCompleted: "lastHoldComplete.wav"
        case .lastSetCompleted: "lastSetComplete.wav"
        case .restCompleted: "restComplete.wav"
        }
    }
}

@MainActor @Observable
final class SessionActivityController {
    static let shared = SessionActivityController()
    private(set) var controlsUnavailable = false
    private(set) var cuesUnavailable = false
    private(set) var canRequestSounds = false
    private(set) var showingSession: UUID?
    @ObservationIgnored var didPublishOpenWorkout: ((UUID?) -> Void)?
    private var updates: Task<Void, Never>?
    private var notificationUpdates: Task<Void, Never>?
    private var deliveredCueCleanup: Task<Void, Never>?
    private var boundaryTask: Task<Void, Never>?
    private let center = UNUserNotificationCenter.current()
    static let cuePrefix = "workout-session."

    func show(_ sessionID: UUID) async {
        await refresh(startFor: sessionID).value
        if canRequestSounds { await requestSounds() }
    }

    @discardableResult
    func refresh(startFor sessionID: UUID? = nil, hideFor dismissedID: UUID? = nil) -> Task<Void, Never> {
        // The first tone is due after three seconds. A delayed Lock Screen publication
        // must not hold up this or the next command's notification requests.
        let previousNotifications = notificationUpdates
        let notifications = Task {
            await previousNotifications?.value
            do {
                try await updateNotifications(for: TrainingStorage.openStore().openWorkout())
            } catch { cuesUnavailable = true }
        }
        notificationUpdates = notifications

        // Intents and foreground changes can overlap across awaits. Publish in commit order
        // and reread the store when a queued update starts.
        let previous = updates
        let task = Task {
            await previous?.value
            do {
                let workout = try TrainingStorage.openStore().openWorkout()
                let state = workout.map(SessionActivity.ContentState.init)
                boundaryTask?.cancel()
                var current: Activity<SessionActivity>?
                for activity in Activity<SessionActivity>.activities {
                    if activity.attributes.sessionID == workout?.id && activity.attributes.sessionID != dismissedID {
                        current = activity
                    } else {
                        await activity.end(nil, dismissalPolicy: .immediate)
                    }
                }
                showingSession = current?.attributes.sessionID
                if let state, let workout {
                    let content = ActivityContent(state: state, staleDate: state.boundary)
                    if let current {
                        await current.update(content)
                    } else if sessionID == workout.id {
                        do {
                            guard ActivityAuthorizationInfo().areActivitiesEnabled else {
                                throw SessionActivityError.unavailable
                            }
                            let activity = try Activity.request(
                                attributes: SessionActivity(sessionID: workout.id),
                                content: content, pushType: nil)
                            showingSession = activity.attributes.sessionID
                        } catch { controlsUnavailable = true }
                    }
                    if showingSession != nil { controlsUnavailable = false }
                    if let date = state.boundary {
                        boundaryTask = Task {
                            do { try await Task.sleep(for: .seconds(max(0, date.timeIntervalSinceNow))) } catch {
                                return
                            }
                            refresh()
                        }
                    }
                } else {
                    controlsUnavailable = false
                }
                await notifications.value
                didPublishOpenWorkout?(workout?.id)
            } catch {
                await notifications.value
                if sessionID != nil { controlsUnavailable = true }
            }
        }
        updates = task
        return task
    }

    func requestSounds() async {
        if await center.notificationSettings().authorizationStatus == .notDetermined {
            do { _ = try await center.requestAuthorization(options: [.alert, .sound]) } catch { cuesUnavailable = true }
        }
        await refresh().value
    }

    func signal(_ kind: WorkoutTimingCue.Kind) async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized && settings.soundSetting == .enabled else { return }
        do {
            try await center.add(.init(identifier: UUID().uuidString, content: notification(for: kind), trigger: nil))
        } catch { cuesUnavailable = true }
    }

    private func notification(for kind: WorkoutTimingCue.Kind) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = String(localized: kind.notificationTitle)
        content.sound = UNNotificationSound(named: .init(rawValue: kind.soundFile))
        content.threadIdentifier = Self.cuePrefix
        content.userInfo = ["workoutCue": kind.rawValue]
        return content
    }

    private func updateNotifications(for workout: OpenWorkout?) async throws {
        let settings = await center.notificationSettings()
        let allowed = settings.authorizationStatus == .authorized && settings.soundSetting == .enabled
        canRequestSounds = workout != nil && settings.authorizationStatus == .notDetermined
        cuesUnavailable = workout != nil && !allowed && !canRequestSounds
        let prefix = Self.cuePrefix
        let requests = await center.pendingNotificationRequests().filter { $0.identifier.hasPrefix(prefix) }
        let pending = Set(requests.map(\.identifier))
        var desired: [String: WorkoutTimingCue] = [:]
        defer { scheduleDeliveredCueCleanup(at: desired.values.map(\.date)) }
        if allowed, let workout {
            for cue in workout.timingCues where cue.date > .now {
                let key = "\(prefix)\(workout.id).\(cue.kind.rawValue).\(cue.date.timeIntervalSinceReferenceDate)"
                desired[key] = cue
            }
        }
        // At expiry the repository may already show the next set while iOS is still delivering its cue.
        let obsolete = requests.filter { request in
            let deadline = request.content.userInfo["deadline"] as? Double ?? .infinity
            return desired[request.identifier] == nil && deadline > Date.now.timeIntervalSinceReferenceDate
        }
        center.removePendingNotificationRequests(withIdentifiers: obsolete.map(\.identifier))
        for (id, cue) in desired.sorted(by: { $0.value.date < $1.value.date }) where !pending.contains(id) {
            let interval = cue.date.timeIntervalSinceNow
            guard interval > 0 else { continue }
            let content = notification(for: cue.kind)
            content.userInfo["deadline"] = cue.date.timeIntervalSinceReferenceDate
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            try await center.add(.init(identifier: id, content: content, trigger: trigger))
        }
    }

    private func scheduleDeliveredCueCleanup(at cueDates: [Date]) {
        deliveredCueCleanup?.cancel()
        deliveredCueCleanup = Task {
            await keepLatestDeliveredCue()
            // iOS may still be presenting a cue when its timer or Lock Screen action returns.
            for date in [.now] + cueDates.sorted() {
                do {
                    try await Task.sleep(for: .seconds(max(0, date.addingTimeInterval(1).timeIntervalSinceNow)))
                } catch { return }
                await keepLatestDeliveredCue()
            }
        }
    }

    private func keepLatestDeliveredCue() async {
        let cues = await center.deliveredNotifications().filter {
            $0.request.content.threadIdentifier == Self.cuePrefix
        }
        guard !Task.isCancelled, cues.count > 1,
            let latest = cues.max(by: { ($0.date, $0.request.identifier) < ($1.date, $1.request.identifier) })
        else { return }
        let older = cues.map(\.request.identifier).filter { $0 != latest.request.identifier }
        center.removeDeliveredNotifications(withIdentifiers: older)
    }
}
