import AVFAudio
import AlarmKit
import OSLog
import SwiftUI
import TrainingInterface
import TrainingRepositories
import UserNotifications

extension HoldCue {
    var title: LocalizedStringResource {
        switch self {
        case .firstHold: "First hold"
        case .holdPause: "Pause between holds"
        case .lastHold: "Last hold"
        case .lastHoldComplete: "Last hold complete · Rest"
        case .lastSetComplete: "Last set complete"
        case .restComplete: "Rest complete · Next set ready"
        }
    }

    var notificationID: String { "hold-trial." + rawValue }

    static func clearDeliveredNotifications() {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: allCases.map(\.notificationID))
    }
}

private actor WorkoutCuePlayer {
    private var player: AVAudioPlayer?

    func start(_ next: AVAudioPlayer) -> Bool {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, options: .duckOthers)
            try session.setActive(true)
            player = next
            // AVAudioPlayer.play() also activates its session synchronously.
            if next.play() { return true }
        } catch {
            // The notification delegate can fall back to the system sound.
        }
        deactivate()
        return false
    }

    func release(_ finished: AVAudioPlayer) {
        guard player === finished else { return }
        deactivate()
    }

    private func deactivate() {
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

final class HoldAudioDelegate: NSObject, ObservableObject, UIApplicationDelegate, UNUserNotificationCenterDelegate,
    AVAudioPlayerDelegate
{
    private let cuePlayer = WorkoutCuePlayer()
    private var playback: Task<Void, Never>?
    private var foregroundCues = ForegroundWorkoutCues()
    private let audioLog = Logger(subsystem: "HotFace", category: "WorkoutAudio")

    func schedule(_ cues: [WorkoutTimingCue]) {
        playback?.cancel()
        foregroundCues.update(cues, at: .now)
        guard foregroundCues.nextDate != nil else { return }
        playback = Task {
            // When authorized, iOS delivers the same cue in either app state.
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            guard !Task.isCancelled else { return }
            if settings.authorizationStatus == .authorized && settings.soundSetting == .enabled {
                foregroundCues = ForegroundWorkoutCues()
                return
            }
            while let deadline = foregroundCues.nextDate {
                do { try await Task.sleep(for: .seconds(max(0, deadline.timeIntervalSinceNow))) } catch { return }
                guard !Task.isCancelled else { return }
                if let cue = foregroundCues.takeDue(at: .now), UIApplication.shared.applicationState == .active {
                    play(cue.kind)
                }
            }
        }
    }

    func stopScheduling() {
        playback?.cancel()
        foregroundCues = ForegroundWorkoutCues()
    }

    func play(_ kind: WorkoutTimingCue.Kind) {
        Task {
            if await self.play(soundFile: kind.soundFile) {
                self.audioLog.info("Started workout cue \(kind.rawValue, privacy: .public)")
            } else {
                self.audioLog.error("Could not play workout cue \(kind.rawValue, privacy: .public)")
            }
        }
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        HealthWorkoutController.shared.configure()
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions
    {
        if let raw = notification.request.content.userInfo["workoutCue"] as? String,
            let kind = WorkoutTimingCue.Kind(rawValue: raw)
        {
            let started = await play(soundFile: kind.soundFile)
            return started ? [.banner] : [.banner, .sound]
        }
        guard let cue = HoldCue(rawValue: notification.request.content.userInfo["holdCue"] as? String ?? "") else {
            return [.banner, .sound]
        }
        let started = await play(soundFile: cue.soundFile)
        return started ? [] : [.sound]
    }

    private func play(soundFile: String) async -> Bool {
        guard let url = Bundle.main.url(forResource: soundFile, withExtension: nil),
            let next = try? AVAudioPlayer(contentsOf: url)
        else { return false }
        next.delegate = self
        return await cuePlayer.start(next)
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { await cuePlayer.release(player) }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { await cuePlayer.release(player) }
    }
}

struct HoldAudioProbe: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("holdTrial") private var savedTrial = Data()
    @AppStorage("holdTrialUsesAlarms") private var activeAlarms = false
    @AppStorage("holdTrialAlarmIDs") private var alarmIDs = Data()
    @AppStorage("holdTrialPrefersAlarms") private var useAlarms = false
    @State private var automatic = true
    @State private var pause = 3
    @State private var longHold = false
    @State private var scheduling = false
    @State private var errorMessage: String?

    private var trial: HoldTrial? { try? JSONDecoder().decode(HoldTrial.self, from: savedTrial) }
    private let center = UNUserNotificationCenter.current()

    var body: some View {
        Section("Hold audio test") {
            if let trial {
                LabeledContent("Audio method") {
                    if activeAlarms { Text("System alarms") } else { Text("Local notifications") }
                }
                TimelineView(.periodic(from: .now, by: 1)) { tick in
                    let now = tick.date
                    Text("Set \(trial.set)")
                    if let last = trial.events.last(where: { $0.date <= now }) {
                        Text(last.cue.title)
                    } else {
                        Text("Get ready")
                    }
                    if let next = trial.events.first(where: { $0.date > now }) {
                        LabeledContent(next.cue.title) {
                            Text(timerInterval: now...next.date, countsDown: true, showsHours: false)
                        }
                    }
                    if let next = trial.continuation(at: now) {
                        Button {
                            if let current = trial.continuation(at: .now) { schedule(current) }
                        } label: {
                            if next.set == trial.set { Text("Start last hold") } else { Text("Start second set") }
                        }
                    }
                }
                Button("End audio test") {
                    do {
                        try clearAlerts()
                        savedTrial = Data()
                        errorMessage = nil
                    } catch { errorMessage = error.localizedDescription }
                }
            } else {
                Picker("Audio method", selection: $useAlarms) {
                    Text("Local notifications").tag(false)
                    Text("System alarms").tag(true)
                }
                Toggle("Automatically start last hold", isOn: $automatic)
                DurationPicker("Pause between holds", seconds: $pause, range: 1...10)
                Toggle("Use 1:30 holds for reboot test", isOn: $longHold)
                Button("Start audio test") {
                    scheduling = true
                    Task { @MainActor in
                        defer { scheduling = false }
                        do {
                            if useAlarms {
                                guard try await AlarmManager.shared.requestAuthorization() == .authorized else {
                                    throw ProbeError.alarmPermission
                                }
                            } else {
                                _ = try await center.requestAuthorization(options: [.alert, .sound])
                                let settings = await center.notificationSettings()
                                guard settings.authorizationStatus == .authorized, settings.soundSetting == .enabled
                                else {
                                    errorMessage = String(
                                        localized: "Allow notifications and sounds in Settings to run the audio test.")
                                    return
                                }
                            }
                            activeAlarms = useAlarms
                            let first = HoldTrial(
                                set: 1, startsAutomatically: automatic, pauseDuration: Double(pause),
                                holdDuration: longHold ? 90 : 6, now: .now)
                            try await install(first)
                        } catch { errorMessage = error.localizedDescription }
                    }
                }
            }
            if let errorMessage { Text(verbatim: errorMessage) }
        }
        .disabled(scheduling)
        .onChange(of: scenePhase, initial: true) {
            if scenePhase == .active { HoldCue.clearDeliveredNotifications() }
        }
    }

    private func schedule(_ next: HoldTrial) {
        scheduling = true
        Task { @MainActor in
            defer { scheduling = false }
            do { try await install(next) } catch { errorMessage = error.localizedDescription }
        }
    }

    private func install(_ trial: HoldTrial) async throws {
        let data = try JSONEncoder().encode(trial)
        try clearAlerts()
        do {
            if activeAlarms {
                let ids = trial.events.map { _ in UUID() }
                alarmIDs = try JSONEncoder().encode(ids)
                for (event, id) in zip(trial.events, ids) {
                    _ = try await WorkoutController.shared.schedule(
                        at: event.date, title: event.cue.title,
                        id: id, sound: .named(event.cue.soundFile))
                }
            } else {
                for event in trial.events {
                    try await scheduleNotification(for: event, set: trial.set)
                }
            }
            savedTrial = data
            errorMessage = nil
        } catch {
            try clearAlerts()
            throw error
        }
    }

    private func scheduleNotification(for event: HoldEvent, set: Int) async throws {
        let content = UNMutableNotificationContent()
        content.threadIdentifier = "hold-trial"
        content.title = String(localized: event.cue.title)
        content.body = String(localized: "Set \(set)")
        content.sound = UNNotificationSound(named: .init(rawValue: event.cue.soundFile))
        content.userInfo = ["holdCue": event.cue.rawValue]
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(0.1, event.date.timeIntervalSinceNow), repeats: false)
        try await center.add(.init(identifier: event.cue.notificationID, content: content, trigger: trigger))
    }

    private func clearAlerts() throws {
        if !alarmIDs.isEmpty {
            let ids = try JSONDecoder().decode([UUID].self, from: alarmIDs)
            try WorkoutController.shared.cancel(ids)
            alarmIDs = Data()
        }
        center.removePendingNotificationRequests(withIdentifiers: HoldCue.allCases.map(\.notificationID))
        HoldCue.clearDeliveredNotifications()
    }
}
