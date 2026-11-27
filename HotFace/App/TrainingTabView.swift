import SwiftUI
import TrainingAdapters
import TrainingDomain
import TrainingInterface
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
                HistoryView()
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
    @Environment(\.scenePhase) private var scenePhase
    @State private var active: ManualRoutine?
    @State private var cycle: RoutineCycle?
    @State private var openWorkout: OpenWorkout?
    @State private var presentedWorkout: OpenWorkout?
    @State private var updateFailed = false
    @State private var discardID: UUID?
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
                    let boundary = presentedWorkout == nil ? openWorkout.nextBoundary : nil
                    List {
                        SessionExerciseRows(workout: openWorkout, header: openWorkout.prescription.day.name) { action in
                            do {
                                _ = try TrainingStorage.openStore().apply(
                                    SessionCommand(sessionID: openWorkout.id, action: action),
                                    clock: SystemWorkoutClock())
                                reload()
                                SessionActivityController.shared.refresh()
                            } catch {
                                updateFailed = true
                                reload()
                            }
                        }
                        .id(openWorkout.id)
                        Section {
                            Button("Continue workout") { presentedWorkout = openWorkout }
                            Button("Finish workout") { confirmsFinish = true }
                            Button("Discard workout", role: .destructive) { discardID = openWorkout.id }
                        }
                    }
                    .toolbar { if openWorkout.timer == nil { EditButton() } }
                    .task(id: boundary) {
                        guard let boundary else { return }
                        do { try await Task.sleep(for: .seconds(max(0, boundary.timeIntervalSinceNow))) } catch {
                            return
                        }
                        reload()
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
            .modifier(DiscardWorkoutConfirmation(sessionID: $discardID, didDiscard: reload))
            .confirmationDialog("Finish workout", isPresented: $confirmsFinish, titleVisibility: .visible) {
                Button("Finish workout") { finishOpenWorkout() }
            } message: {
                Text("Your completed sets will be kept.")
            }
            .sheet(item: $summary, onDismiss: reload) { value in
                FinishedWorkoutView(summary: value) { summary = nil }
            }
            .alert("Could not update workout", isPresented: $updateFailed) { Button("OK") {} }
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
        .onChange(of: scenePhase) { if scenePhase == .active { reload() } }
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
            openWorkout = workout
            if scenePhase == .active { audio.schedule(workout?.timingCues ?? []) }
            let needsRoutine = workout == nil && presentedWorkout == nil
            if needsRoutine && summary == nil {
                summary = try store.pendingWorkoutSummary()
            }
            let routine = try needsRoutine && summary == nil ? store.activeRoutine() : nil
            cycle = try routine.map { try store.currentCycle(for: $0.id) }
            active = routine
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

struct SessionExerciseRows: View {
    @Environment(\.editMode) private var editMode
    @Environment(\.locale) private var locale
    @State private var hidesCompleted = false
    let workout: OpenWorkout
    var header: String? = nil
    let apply: (SessionCommand.Action) -> Void

    var body: some View {
        let pending = Set(workout.pendingExercises.map(\.id))
        let blocks = SessionExerciseBlock.blocks(in: workout.prescription.day)
        let visible = blocks.filter { block in
            !hidesCompleted
                || block.exercises.contains { pending.contains($0.id) || workout.skippedExerciseIDs.contains($0.id) }
        }
        let byAnchor = Dictionary(uniqueKeysWithValues: visible.map { ($0.id, $0) })
        let sections = ExerciseGroupSection.sections(
            for: RoutineDay(name: "", exercises: visible.map { $0.exercises[0] }))
        Section {
            Toggle("Hide completed", isOn: $hidesCompleted)
        } header: {
            if let header { Text(verbatim: header) }
        }
        if editMode?.wrappedValue.isEditing == true {
            ForEach(sections) { section in
                let blocks = section.exercises.compactMap { byAnchor[$0.id] }
                Section {
                    ForEach(blocks) { block in
                        VStack(alignment: .leading) {
                            if block.exercises.count > 1 { Text("Superset").font(.caption.bold()) }
                            ForEach(members(of: block, pending: pending)) { exercise in
                                memberLabel(exercise, pending: pending)
                            }
                        }
                    }
                    .onMove { offsets, destination in
                        let ids = blocks.map(\.id)
                        var reordered = ids
                        reordered.move(fromOffsets: offsets, toOffset: destination)
                        apply(.reorderBlocks(original: ids, reordered: reordered, moved: offsets.map { ids[$0] }))
                    }
                } header: {
                    heading(for: section)
                }
            }
        } else {
            ForEach(sections) { section in
                let blocks = section.exercises.compactMap { byAnchor[$0.id] }
                Section {
                    ForEach(blocks) { block in
                        let members = members(of: block, pending: pending)
                        ForEach(members) { exercise in
                            VStack(alignment: .leading) {
                                if block.exercises.count > 1 && exercise.id == members.first?.id {
                                    Text("Superset").font(.caption.bold())
                                }
                                memberLabel(exercise, pending: pending)
                            }
                            .swipeActions(allowsFullSwipe: false) {
                                if pending.contains(exercise.id), workout.timer == nil {
                                    Button("Skip exercise") { apply(.skipAndAdvance(exerciseID: exercise.id)) }
                                    Button("Postpone exercise") {
                                        apply(.moveExercise(id: exercise.id, toFront: false))
                                    }
                                    Button("Select exercise") {
                                        apply(.moveExercise(id: exercise.id, toFront: true))
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    heading(for: section)
                }
            }
        }
    }

    @ViewBuilder
    private func heading(for section: ExerciseGroupSection) -> some View {
        if let heading = section.heading(locale: locale) { Text(verbatim: heading) }
    }

    private func members(of block: SessionExerciseBlock, pending: Set<UUID>) -> [ExercisePrescription] {
        block.exercises.filter {
            !hidesCompleted || pending.contains($0.id) || workout.skippedExerciseIDs.contains($0.id)
        }
    }

    private func memberLabel(_ exercise: ExercisePrescription, pending: Set<UUID>) -> some View {
        HStack {
            Text(verbatim: exercise.name)
            Spacer()
            if workout.skippedExerciseIDs.contains(exercise.id) {
                Image(systemName: "forward.end").accessibilityLabel("Skipped")
            } else if !pending.contains(exercise.id) {
                Image(systemName: "checkmark").accessibilityLabel("Completed")
            }
        }
    }
}

struct DiscardWorkoutConfirmation: ViewModifier {
    @EnvironmentObject private var audio: HoldAudioDelegate
    @Binding var sessionID: UUID?
    let didDiscard: () -> Void
    @State private var failed = false

    func body(content: Content) -> some View {
        content.alert(
            "Discard workout?",
            isPresented: Binding(
                get: { sessionID != nil }, set: { if !$0 { sessionID = nil } }),
            presenting: sessionID
        ) { id in
            Button("Discard workout", role: .destructive) {
                do {
                    _ = try TrainingStorage.openStore().apply(
                        SessionCommand(sessionID: id, action: .discard), clock: SystemWorkoutClock())
                    audio.schedule([])
                    if HealthWorkoutController.shared.workoutID == id { HealthWorkoutController.shared.end() }
                    SessionActivityController.shared.refresh(hideFor: id)
                    didDiscard()
                } catch { failed = true }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Your sets will be removed. Ratings and changes saved as usual will be kept.")
        }
        .alert("Could not discard workout", isPresented: $failed) { Button("OK") {} }
    }
}
