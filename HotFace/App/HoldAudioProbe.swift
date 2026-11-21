import AVFAudio
import AlarmKit
import SwiftUI
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

final class HoldAudioDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        guard let cue = HoldCue(rawValue: notification.request.content.userInfo["holdCue"] as? String ?? "") else {
            return [.banner, .sound]
        }
        guard let url = Bundle.main.url(forResource: cue.soundFile, withExtension: nil) else { return [.sound] }
        let session = AVAudioSession.sharedInstance()
        do {
            let next = try AVAudioPlayer(contentsOf: url)
            try session.setCategory(.playback, options: .duckOthers)
            try session.setActive(true)
            next.delegate = self
            player = next
            if next.play() { return [] }
        } catch {
            // Fall back to the notification sound if the audio session is unavailable.
        }
        releaseAudio()
        return [.sound]
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if self.player === player { releaseAudio() }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if self.player === player { releaseAudio() }
    }

    private func releaseAudio() {
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
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
                    Text(activeAlarms ? "System alarms" : "Local notifications")
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
                        LabeledContent(next.cue.title) { Text(timerInterval: now...next.date, countsDown: true) }
                    }
                    if let next = trial.continuation(at: now) {
                        Button(next.set == trial.set ? "Start last hold" : "Start second set") {
                            if let current = trial.continuation(at: .now) { schedule(current) }
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
                Stepper("Pause between holds: \(pause) s", value: $pause, in: 1...10)
                Toggle("Use 90 s holds for reboot test", isOn: $longHold)
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
                                guard settings.authorizationStatus == .authorized, settings.soundSetting == .enabled else {
                                    errorMessage = String(localized: "Allow notifications and sounds in Settings to run the audio test.")
                                    return
                                }
                            }
                            activeAlarms = useAlarms
                            let first = HoldTrial(set: 1, startsAutomatically: automatic, pauseDuration: Double(pause),
                                                  holdDuration: longHold ? 90 : 6, now: .now)
                            try await install(first)
                        } catch { errorMessage = error.localizedDescription }
                    }
                }
            }
            if let errorMessage { Text(errorMessage) }
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
            do { try await install(next) }
            catch { errorMessage = error.localizedDescription }
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
                    _ = try await WorkoutController.shared.schedule(at: event.date, title: event.cue.title,
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
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(0.1, event.date.timeIntervalSinceNow), repeats: false)
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
