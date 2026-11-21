import ActivityKit
import SwiftUI
import WidgetKit

// This dedicated activity wakes the extension for the command-line storage probe.
struct StorageTrialWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StorageTrialAttributes.self) { context in
            Text("Storage test")
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) { Text("Storage test") }
            } compactLeading: {
                Image(systemName: "internaldrive")
            } compactTrailing: {
                EmptyView()
            } minimal: {
                Image(systemName: "internaldrive")
            }
        }
    }

    private static let commandQueue = DispatchQueue(label: "StorageTrial.commands", qos: .userInitiated)
    private static let listener: Void = {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), nil,
            { _, _, _, _, _ in commandQueue.async { submitPendingCommand() } },
            StorageTrial.commandNotification as CFString, nil, .deliverImmediately)
        // Handle a command posted before WidgetKit launched this process.
        commandQueue.async { submitPendingCommand() }
    }()

    static func listenForCommands() { _ = listener }

    private static func submitPendingCommand() {
        guard let command = try? StorageTrial.pendingCommand(),
            let value = try? String(contentsOf: command, encoding: .utf8),
            let id = UUID(uuidString: value)
        else { return }
        do {
            let trial = try StorageTrial(id: id)
            // WidgetKit can launch more than one extension process for one activity.
            let claim = trial.store.directory.appendingPathComponent("widget-started")
            do { try Data().write(to: claim, options: .withoutOverwriting) } catch let error as CocoaError
                where error.code == .fileWriteFileExists
            { return }
            try trial.submit(.widget)
        } catch { NSLog("Storage trial %@: %@", id.uuidString, String(describing: error)) }
    }
}
