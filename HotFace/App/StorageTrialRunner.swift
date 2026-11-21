import ActivityKit
import Foundation

enum StorageTrialRunner {
    // Launch with a fresh UUID, then relaunch with the same UUID to check recovery.
    @MainActor
    static func runIfRequested() async {
        let arguments = ProcessInfo.processInfo.arguments
        guard let mode = arguments.firstIndex(where: { ["-storage-trial", "-recover-storage-trial"].contains($0) }),
            arguments.indices.contains(mode + 1), let id = UUID(uuidString: arguments[mode + 1])
        else { return }
        let replay = arguments[mode] == "-recover-storage-trial"
        var activity: Activity<StorageTrialAttributes>?
        let result: String
        do {
            let trial = try StorageTrial(id: id)
            var writer: Task<Void, Error>?
            if !replay {
                let marker = trial.store.directory.appendingPathComponent("started")
                try Data().write(to: marker, options: .withoutOverwriting)
                try Data(id.uuidString.utf8).write(to: StorageTrial.pendingCommand(), options: .atomic)
                writer = Task.detached { try trial.submit(.app) }
                activity = try Activity.request(
                    attributes: StorageTrialAttributes(trialID: id),
                    content: ActivityContent(state: .init(), staleDate: nil))
                CFNotificationCenterPostNotification(
                    CFNotificationCenterGetDarwinNotifyCenter(),
                    CFNotificationName(StorageTrial.commandNotification as CFString), nil, nil, true)
            }
            try await writer?.value
            result = try await Task.detached {
                if !replay {
                    try trial.wait(for: "widget.json")
                }
                return "PASS " + (try trial.verify(replay: replay))
            }.value
        } catch {
            result = "FAIL " + String(describing: error)
        }
        if !replay, let command = try? StorageTrial.pendingCommand(),
            (try? String(contentsOf: command, encoding: .utf8)) == id.uuidString
        {
            try? FileManager.default.removeItem(at: command)
        }
        await activity?.end(nil, dismissalPolicy: .immediate)
        let name = "\(id.uuidString)-\(replay ? "recovery" : "race").txt"
        do {
            try result.write(to: URL.documentsDirectory.appendingPathComponent(name), atomically: true, encoding: .utf8)
        } catch { print("Storage trial report: \(error)") }
        print("Storage trial \(name): \(result)")
    }
}
