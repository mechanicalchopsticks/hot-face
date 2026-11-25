import SwiftUI
import TrainingAdapters
import TrainingDomain
import TrainingRepositories

struct TrainingTabView: View {
    private enum Destination { case train, routines, history, settings }
    @State private var selectedTab = Destination.train
    @State private var newRoutineGymID: UUID?

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Train", systemImage: "figure.strengthtraining.traditional", value: .train) {
                ActiveRoutineView()
            }
            Tab("Routines", systemImage: "list.bullet.clipboard", value: .routines) {
                RoutinesView(newRoutineGymID: $newRoutineGymID)
            }
            Tab("History", systemImage: "clock", value: .history) {
                EmptySection(
                    "History",
                    heading: "No workouts yet",
                    systemImage: "clock",
                    message: "Your finished workouts will appear here.")
            }
            Tab("Settings", systemImage: "gearshape", value: .settings) {
                GymSettingsView { gymID in
                    newRoutineGymID = gymID
                    selectedTab = .routines
                }
            }
        }
    }
}

private struct ActiveRoutineView: View {
    @EnvironmentObject private var audio: HoldAudioDelegate
    @State private var active: ManualRoutine?
    @State private var cycle: RoutineCycle?
    @State private var openWorkout: OpenWorkout?
    @State private var presentedWorkout: OpenWorkout?
    @State private var confirmsFinish = false
    @State private var summary: WorkoutSummary?
    @State private var finishFailed = false
    @State private var loadFailed = false
    @State private var startError: LocalizedStringKey?

    var body: some View {
        NavigationStack {
            Group {
                if loadFailed {
                    ContentUnavailableView {
                        Label("Could not load routines", systemImage: "exclamationmark.triangle")
                    } actions: {
                        Button("Try again", action: reload)
                    }
                } else if let openWorkout {
                    List {
                        Section {
                            Button("Continue workout") { presentedWorkout = openWorkout }
                            Button("Finish workout") { confirmsFinish = true }
                        } header: {
                            Text(verbatim: openWorkout.prescription.day.name)
                        }
                    }
                } else if let active, let cycle {
                    List {
                        Section {
                            ForEach(cycle.availableDayIDs, id: \.self) { id in
                                if let day = active.plan.days.first(where: { $0.id == id }) {
                                    Button {
                                        start(day: day, routine: active, cycle: cycle)
                                    } label: {
                                        Text(verbatim: day.name)
                                    }
                                }
                            }
                        } header: {
                            Text(verbatim: active.plan.name)
                        }
                    }
                } else {
                    EmptySectionContent(
                        heading: "No active routine", systemImage: "figure.strengthtraining.traditional",
                        message: "Your training days will appear here when a routine is active.")
                }
            }
            .navigationTitle("Train")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Finish workout", isPresented: $confirmsFinish, titleVisibility: .visible) {
                Button("Finish workout") { finishOpenWorkout() }
            } message: {
                Text("Your completed sets will be kept.")
            }
            .sheet(item: $summary, onDismiss: reload) { value in
                FinishedWorkoutView(summary: value) { summary = nil }
            }
            .alert("Could not finish workout", isPresented: $finishFailed) { Button("OK") {} }
            .sheet(item: $presentedWorkout, onDismiss: closeWorkoutScreen) { workout in
                WorkoutSessionView(workout: workout)
                    .onAppear { SessionActivityController.shared.refresh(startFor: workout.id) }
            }
            .alert(
                "Could not start workout",
                isPresented: Binding(get: { startError != nil }, set: { if !$0 { startError = nil } }),
                presenting: startError
            ) { _ in
                Button("OK") {}
            } message: { message in
                Text(message)
            }
        }
        .onAppear(perform: reload)
        .onReceive(NotificationCenter.default.publisher(for: .workoutControlPerformed)) { _ in reload() }
    }

    private func closeWorkoutScreen() {
        HealthWorkoutController.shared.end()
        if let id = openWorkout?.id { SessionActivityController.shared.refresh(hideFor: id) }
        reload()
    }

    private func finishOpenWorkout() {
        guard let openWorkout else { return }
        do {
            let store = try TrainingStorage.openStore()
            _ = try store.apply(SessionCommand(sessionID: openWorkout.id, action: .finish), clock: SystemWorkoutClock())
            audio.schedule([])
            SessionActivityController.shared.refresh()
            summary = try store.workoutSummary(id: openWorkout.id)
            reload()
        } catch { finishFailed = true }
    }

    private func reload() {
        do {
            let store = try TrainingStorage.openStore()
            let workout = try store.openWorkout()
            let routine = try workout == nil ? store.activeRoutine() : nil
            cycle = try routine.map { try store.currentCycle(for: $0.id) }
            active = routine
            openWorkout = workout
            loadFailed = false
        } catch { loadFailed = true }
    }

    private func start(day: RoutineDay, routine: ManualRoutine, cycle: RoutineCycle) {
        do {
            let store = try TrainingStorage.openStore()
            _ = try store.apply(
                SessionCommand(
                    sessionID: UUID(),
                    action: .start(routineID: routine.id, gymID: routine.gymID, dayID: day.id, cycleID: cycle.id)),
                clock: SystemWorkoutClock())
            let workout = try store.openWorkout()
            openWorkout = workout
            presentedWorkout = workout
        } catch SessionCommandError.missingEquipment {
            startError = "Assigned equipment was deleted. Choose a replacement."
        } catch {
            reload()
            startError = "Check your routine and try again."
        }
    }
}

private struct EmptySection: View {
    let title: LocalizedStringKey
    let heading: LocalizedStringKey
    let systemImage: String
    let message: LocalizedStringKey

    init(_ title: LocalizedStringKey, heading: LocalizedStringKey, systemImage: String, message: LocalizedStringKey) {
        self.title = title
        self.heading = heading
        self.systemImage = systemImage
        self.message = message
    }

    var body: some View {
        NavigationStack {
            EmptySectionContent(heading: heading, systemImage: systemImage, message: message)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct EmptySectionContent: View {
    let heading: LocalizedStringKey
    let systemImage: String
    let message: LocalizedStringKey

    var body: some View {
        GeometryReader { viewport in
            ScrollView {
                ContentUnavailableView {
                    Label(heading, systemImage: systemImage)
                } description: {
                    Text(message)
                }
                .frame(maxWidth: .infinity, minHeight: viewport.size.height)
            }
            .defaultScrollAnchor(.top, for: .initialOffset)
        }
    }
}
