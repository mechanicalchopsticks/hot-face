import HealthKit
import Observation

@MainActor @Observable
final class HealthWorkoutController: NSObject, HKWorkoutSessionDelegate {
    static let shared = HealthWorkoutController()

    enum Status { case idle, starting, running, denied, unavailable }
    private(set) var status = Status.idle
    private(set) var workoutID: UUID?
    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var startup: Task<Void, Never>?
    private var recovery: Task<Void, Never>?
    private let recoveryKey = "activeHealthWorkoutID"

    func configure() {
        SessionActivityController.shared.didPublishOpenWorkout = { [weak self] openID in
            guard let self, let workoutID, workoutID != openID else { return }
            // A newer workout may have started while ActivityKit was publishing.
            do {
                if try TrainingStorage.openStore().openWorkout()?.id != workoutID { end() }
            } catch { return }
        }

        let defaults = UserDefaults.standard
        let previousID = defaults.string(forKey: recoveryKey).flatMap(UUID.init(uuidString:))
        let trialKey = "healthWorkoutTrialInProgress"
        guard previousID != nil || defaults.bool(forKey: trialKey) else { return }
        workoutID = previousID
        recovery = Task {
            defer {
                defaults.removeObject(forKey: trialKey)
                recovery = nil
            }
            do {
                let previous = try await store.recoverActiveWorkoutSession()
                if let previous {
                    // The old one-set trial had no associated HotFace workout identifier.
                    if let previousID, workoutID == previousID,
                        previous.state == .running || previous.state == .paused,
                        (try? TrainingStorage.openStore().openWorkout()?.id) == previousID
                    {
                        session = previous
                        previous.delegate = self
                        status = .running
                        return
                    }
                    discard(previous)
                }
                defaults.removeObject(forKey: recoveryKey)
            } catch { status = .unavailable }
        }
    }

    func begin(_ id: UUID) {
        if workoutID != id {
            end()
            workoutID = id
        }
        guard startup == nil else { return }
        let workoutType = HKObjectType.workoutType()
        if session != nil && store.authorizationStatus(for: workoutType) == .sharingAuthorized { return }
        if let session {
            discard(session)
            self.session = nil
        }
        status = .starting
        startup = Task {
            defer { if !Task.isCancelled { startup = nil } }
            await recovery?.value
            guard !Task.isCancelled, workoutID == id, session == nil else { return }
            guard HKHealthStore.isHealthDataAvailable() else {
                status = .unavailable
                return
            }
            do {
                if store.authorizationStatus(for: workoutType) == .notDetermined {
                    try await store.requestAuthorization(toShare: [workoutType], read: [])
                }
                guard !Task.isCancelled, workoutID == id else { return }
                guard store.authorizationStatus(for: workoutType) == .sharingAuthorized else {
                    status = .denied
                    return
                }
                guard try TrainingStorage.openStore().openWorkout()?.id == id else {
                    end()
                    return
                }
                let configuration = HKWorkoutConfiguration()
                configuration.activityType = .traditionalStrengthTraining
                configuration.locationType = .indoor
                let current = try HKWorkoutSession(healthStore: store, configuration: configuration)
                session = current
                current.delegate = self
                UserDefaults.standard.set(id.uuidString, forKey: recoveryKey)
                current.startActivity(with: .now)
            } catch {
                if !Task.isCancelled && workoutID == id { status = .unavailable }
            }
        }
    }

    func end() {
        startup?.cancel()
        startup = nil
        workoutID = nil
        if let session { discard(session) }
        session = nil
        UserDefaults.standard.removeObject(forKey: recoveryKey)
        status = .idle
    }

    private func discard(_ session: HKWorkoutSession) {
        // HotFace owns the training record. HealthKit provides the active workout lifetime.
        session.delegate = nil
        session.associatedWorkoutBuilder().discardWorkout()
        if session.state != .ended { session.end() }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState, date: Date
    ) {
        Task { @MainActor in
            guard session === workoutSession else { return }
            switch toState {
            case .running: status = .running
            case .ended, .stopped:
                end()
                status = .unavailable
            default: break
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            guard session === workoutSession else { return }
            end()
            status = .unavailable
        }
    }
}
