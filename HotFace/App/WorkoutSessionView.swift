import SwiftUI
import TrainingAdapters
import TrainingDomain
import TrainingInterface
import TrainingRepositories

struct WorkoutSessionView: View {
    @EnvironmentObject private var audio: HoldAudioDelegate
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @WeightProgressionPreference private var progressionMode
    @State var workout: OpenWorkout
    @State private var actionError: LocalizedStringKey?
    @State private var discardID: UUID?
    @State private var confirmsFinish = false

    @State private var correcting: OpenWorkout.Rest?

    @State private var adjusting: ExercisePrescription?

    @State private var choosingExercise = false

    @State private var summary: WorkoutSummary?
    @State private var progression: (id: UUID, exerciseID: UUID, advice: ProgressionAdvice, loads: [ExerciseLoad])?
    @State private var declinedProgressionFor: UUID?

    var body: some View {
        if let summary {
            FinishedWorkoutView(summary: summary) { dismiss() }
        } else {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                training(at: timeline.date)
            }
        }
    }

    private func training(at date: Date) -> some View {
        let rest = workout.activeRest(at: date)
        let next = workout.nextSet
        let startingID = rest == nil && workout.timer == nil && next?.number == 1 ? next?.exercise.id : nil
        return NavigationStack {
            List {
                let activity = SessionActivityController.shared
                if activity.showingSession != workout.id {
                    Button("Show on Lock Screen") { Task { await activity.show(workout.id) } }
                    if activity.controlsUnavailable { Text("Lock Screen controls are unavailable.") }
                }
                switch HealthWorkoutController.shared.status {
                case .denied: Text("Allow workouts in Health for reliable Lock Screen updates.")
                case .unavailable: Text("Health is unavailable. Lock Screen updates may be delayed.")
                default: EmptyView()
                }
                if activity.canRequestSounds {
                    Button("Enable workout sounds on Lock Screen") { Task { await activity.requestSounds() } }
                }
                if activity.cuesUnavailable { Text("Lock Screen sounds are unavailable. Check notification settings.") }
                if let rest {
                    Section {
                        WorkoutRestCountdown(remaining: rest.endsAt.timeIntervalSince(date))
                        HStack {
                            Button("−0:15") { adjustRest(rest, by: .shorten) }
                                .accessibilityLabel("Shorten rest by 15 seconds")
                            Spacer()
                            Button("+0:15") { adjustRest(rest, by: .extend) }
                                .accessibilityLabel("Extend rest by 15 seconds")
                        }
                        .buttonStyle(.bordered)
                        if let target = rest.feedbackTarget {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("How did \(target.name) feel?").font(.headline)
                                HStack {
                                    Button("Hard") { respondToRest(.answerRestFeedback(setID: rest.id, effort: .hard)) }
                                    Button {
                                        respondToRest(.answerRestFeedback(setID: rest.id, effort: nil))
                                    } label: {
                                        Text(verbatim: "OK")
                                    }
                                    Button("Easy") { respondToRest(.answerRestFeedback(setID: rest.id, effort: .easy)) }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        Button("Correct set") { correcting = rest }
                        Label("Set \(rest.completedSetNumber) completed", systemImage: "checkmark.circle")
                    } header: {
                        Text("Rest")
                    }
                }
                if let set = workout.nextSet {
                    Section {
                        HStack {
                            WorkoutSetHeader(name: set.exercise.name, number: set.number, count: set.count)
                            if rest != nil, let action = workout.postponeAction {
                                Spacer()
                                Button("Postpone") { respondToRest(action) }
                                    .buttonStyle(.bordered)
                            }
                        }
                        if let round = workout.nextSupersetRound {
                            Text("Superset · Round \(round.number) of \(round.count)")
                            ForEach(workout.roundMembers) { member in
                                HStack {
                                    Text(verbatim: member.exercise.name)
                                    Spacer()
                                    switch member.status {
                                    case .completed: Label("Completed", systemImage: "checkmark")
                                    case .current:
                                        if let rest {
                                            let title: LocalizedStringKey =
                                                rest.startsNextRound ? "Starts next round" : "Next exercise"
                                            Label(title, systemImage: "arrow.right")
                                        } else {
                                            Label("Current", systemImage: "play.fill")
                                        }
                                    case .upcoming: Text("Upcoming")
                                    case .skipped: Text("Skipped")
                                    }
                                }.fontWeight(member.status == .current ? .bold : .regular)
                                    .accessibilityElement(children: .combine)
                            }
                        }
                        if let timer = workout.timer {
                            if set.exercise.perSide { Text("Side \(timer.sideNumber) of 2") }
                            if set.exercise.segments.count > 1 {
                                Text("Hold \(timer.holdNumber) of \(set.exercise.segments.count)")
                            }
                            WorkoutPhaseView(workout: timer, at: date)
                        }
                        WorkoutSetPrescription(
                            exercise: set.exercise, equipment: set.equipment, gymID: workout.prescription.gymID)
                    } header: {
                        if rest != nil
                            || (workout.timer == nil && workout.rest == nil
                                && workout.transition == .nextSupersetMember)
                        {
                            switch workout.transition {
                            case .nextSet: Text("Next set")
                            case .nextExercise: Text("Next exercise")
                            case .nextSupersetMember: Text("Next superset member")
                            case nil: EmptyView()
                            }
                        } else if workout.timer == nil {
                            Text("Ready")
                        }
                    }
                    if let progression, progression.exerciseID == startingID {
                        Section("Progression suggestion") {
                            switch progression.advice {
                            case .adjustManually:
                                Text("Review this exercise manually at your current effort balance.")
                                Button("Adjust exercise") { adjusting = set.exercise }
                            case .suggested(let suggestion):
                                ProgressionFields(suggestion: suggestion, loads: progression.loads) {
                                    load, repetitions in
                                    do {
                                        let store = try TrainingStorage.openStore()
                                        try store.acceptProgressionSuggestion(
                                            suggestion, load: load, repetitions: repetitions,
                                            routineID: workout.prescription.routineID,
                                            exerciseID: set.exercise.id, sessionID: workout.id,
                                            clock: SystemWorkoutClock(), mode: progressionMode)
                                        self.progression = nil
                                        try reload(from: store)
                                    } catch {
                                        refresh()
                                        loadProgression(for: startingID)
                                        actionError = "Could not update workout"
                                    }
                                }.id(progression.id)
                            }
                            Button("Continue with current values") {
                                declinedProgressionFor = set.exercise.id
                                self.progression = nil
                            }
                        }
                    }
                } else {
                    Label("All sets completed", systemImage: "checkmark.circle")
                }
            }
            .navigationTitle(Text(verbatim: workout.prescription.day.name))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if workout.nextSet != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button("Exercises") { choosingExercise = true }
                                .disabled(workout.timer != nil)
                            if let next = workout.nextSet {
                                Button("Adjust exercise") { adjusting = next.exercise }
                                    .disabled(workout.timer != nil)
                            }
                            if HealthWorkoutController.shared.status == .running {
                                Label("Health session active", systemImage: "heart")
                            }
                            Button("Finish workout") { confirmsFinish = true }
                            Button("Discard workout", role: .destructive) { discardID = workout.id }
                        } label: {
                            Label("More", systemImage: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $choosingExercise, onDismiss: { loadProgression(for: workout.nextSet?.exercise.id) }) {
                WorkoutExerciseList(workout: workout) { action in try apply(action) }
            }
            .sheet(item: $adjusting) { exercise in
                WorkoutAdjustmentView(exercise: exercise, workout: workout) { action in
                    try apply(action)
                    if progression != nil { loadProgression(for: startingID) }
                }
            }
            .sheet(item: $correcting) { record in
                SetCorrectionView(record: record) { performance in
                    try apply(.correctSet(id: record.id, performance: performance))
                }
            }
            .safeAreaInset(edge: .bottom) { primaryAction(rest: rest, at: date) }
            .onReceive(NotificationCenter.default.publisher(for: .workoutControlPerformed)) { _ in refresh() }
            .onChange(of: scenePhase, initial: true) {
                if scenePhase == .active {
                    refresh()
                    if summary == nil { HealthWorkoutController.shared.begin(workout.id) }
                }
            }
            .task(id: startingID) {
                declinedProgressionFor = nil
                loadProgression(for: startingID)
            }
            .task(id: workout.timer?.exerciseEnd) {
                guard let end = workout.timer?.exerciseEnd else { return }
                try? await Task.sleep(for: .seconds(max(0, end.timeIntervalSinceNow)))
                if !Task.isCancelled { refresh() }
            }
            .modifier(DiscardWorkoutConfirmation(sessionID: $discardID) { dismiss() })
            .confirmationDialog("Finish workout", isPresented: $confirmsFinish, titleVisibility: .visible) {
                Button("Finish workout", action: finish)
            } message: {
                Text("Your completed sets will be kept.")
            }
            .alert(
                actionError ?? "",
                isPresented: Binding(get: { actionError != nil }, set: { if !$0 { actionError = nil } })
            ) {
                Button("OK") {}
            }
        }
    }

    private func loadProgression(for exerciseID: UUID?) {
        do {
            guard let exerciseID, exerciseID != declinedProgressionFor,
                let offer = try TrainingStorage.openStore().progressionOffer(
                    routineID: workout.prescription.routineID, exerciseID: exerciseID, sessionID: workout.id,
                    clock: SystemWorkoutClock(), mode: progressionMode)
            else {
                progression = nil
                return
            }
            if let progression, progression.exerciseID == exerciseID, progression.advice == offer.advice,
                progression.loads == offer.loads
            {
                return
            }
            progression = (UUID(), exerciseID, offer.advice, offer.loads)
        } catch {
            progression = nil
            actionError = "Could not update workout"
        }
    }

    private func primaryAction(rest: OpenWorkout.Rest?, at date: Date) -> some View {
        Group {
            if let rest {
                action("End rest") { adjustRest(rest, by: .end) }
            } else if let set = workout.nextSet {
                if let timer = workout.timer {
                    VStack {
                        if timer.exerciseEnd == nil && timer.pausedSeconds == nil {
                            let sideStart = timer.sideNumber == 2 && timer.holdNumber == 1
                            action(sideStart ? "Start second side" : "Start next hold") {
                                control(.start, set: set, revision: timer.revision)
                            }.disabled(date < (timer.holdAvailableAt ?? .distantPast))
                        } else if timer.pausedSeconds == nil {
                            action("Pause") { control(.pause, set: set, revision: timer.revision) }
                        } else {
                            action("Resume") { control(.resume, set: set, revision: timer.revision) }
                        }
                        if let duration = set.exercise.timedHolds?.first,
                            timer.canCancel(firstHoldDuration: TimeInterval(duration), at: date)
                        {
                            Button("Cancel set") { control(.cancel, set: set, revision: timer.revision) }
                                .buttonStyle(.bordered)
                        }
                        Button {
                            control(.complete, set: set, revision: timer.revision)
                        } label: {
                            if set.exercise.perSide && timer.sideNumber == 1 {
                                Text("Finish side early")
                            } else {
                                Text("Finish set early")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(timer.exerciseStart == nil && timer.pausedSeconds == nil && timer.holdNumber == 1)
                    }
                } else if set.timedDuration != nil {
                    action("Start set") {
                        control(.start, set: set, revision: workout.prescription.timerStartRevision ?? 0)
                    }
                } else {
                    action("Complete set") { complete(set) }
                }
            } else {
                action("Finish workout", perform: finish)
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding()
        .background(.bar)
    }

    private func action(_ title: LocalizedStringKey, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Text(title).frame(maxWidth: .infinity, minHeight: 32)
        }
    }

    private func apply(_ action: SessionCommand.Action) throws {
        let store = try TrainingStorage.openStore()
        _ = try store.apply(SessionCommand(sessionID: workout.id, action: action), clock: SystemWorkoutClock())
        try reload(from: store)
    }

    private func respondToRest(_ action: SessionCommand.Action) {
        do { try apply(action) } catch SessionCommandError.restUnavailable {
            refresh()
        } catch { actionError = "Could not update workout" }
    }

    private func refresh() {
        do { try reload(from: TrainingStorage.openStore()) } catch { actionError = "Could not update workout" }
    }

    private func reload(from store: CoordinatedModelStore) throws {
        let open = try store.openWorkout()
        audio.schedule(open?.timingCues ?? [])
        SessionActivityController.shared.refresh()
        if let updated = open, updated.id == workout.id {
            workout = updated
        } else {
            summary = try store.workoutSummary(id: workout.id)
        }
    }

    private func control(_ action: WorkoutAction, set: OpenWorkout.PendingSet, revision: Int) {
        do {
            let firstSide = set.exercise.perSide && workout.timer?.sideNumber == 1
            try apply(
                .controlTimer(
                    exerciseID: set.exercise.id, number: set.number, expectedRevision: revision, action: action))
            if action == .complete {
                audio.play(firstSide ? .sideCompleted : (set.number == set.count ? .lastSetCompleted : .setCompleted))
            }
        } catch {
            refresh()
            actionError = "Could not update workout"
        }
    }

    private func complete(_ set: OpenWorkout.PendingSet) {
        do {
            try apply(.logCurrentSet(exerciseID: set.exercise.id, number: set.number))
            audio.play(set.number == set.count ? .lastSetCompleted : .setCompleted)
        } catch { actionError = "Could not update workout" }
    }

    private func adjustRest(_ rest: OpenWorkout.Rest, by adjustment: RestAdjustment) {
        do { try apply(.adjustRest(setID: rest.id, adjustment: adjustment)) } catch SessionCommandError.restUnavailable
        {} catch { actionError = "Could not update workout" }
    }

    private func finish() {
        do {
            try apply(.finish)
        } catch { actionError = "Could not finish workout" }
    }
}

private struct ProgressionFields: View {
    @Environment(\.locale) private var locale
    let suggestion: WeightSuggestion
    let loads: [ExerciseLoad]
    let save: (ExerciseLoad, Int) -> Void
    @State private var selectedIndex: Int
    @State private var repetitions: Int

    init(suggestion: WeightSuggestion, loads: [ExerciseLoad], save: @escaping (ExerciseLoad, Int) -> Void) {
        self.suggestion = suggestion
        self.loads = loads
        self.save = save
        _selectedIndex = State(initialValue: loads.firstIndex(of: suggestion.load) ?? 0)
        _repetitions = State(initialValue: suggestion.repetitions)
    }

    var body: some View {
        Text(suggestion.reason.explanation)
        Picker("Load", selection: $selectedIndex) {
            ForEach(loads.indices, id: \.self) { index in
                Text(verbatim: TrainingDisplayFormat.load(loads[index], locale: locale)).tag(index)
            }
        }
        Text(suggestion.load.representation.title).font(.caption)
        Stepper("\(repetitions) reps", value: $repetitions, in: 1...Int.max)
        Button("Save as usual") {
            if loads.indices.contains(selectedIndex) { save(loads[selectedIndex], repetitions) }
        }
    }
}

struct FinishedWorkoutView: View {
    @State var summary: WorkoutSummary
    let close: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @State private var failed = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(verbatim: summary.name)
                    if summary.partial { Text("Partially completed") }
                }
                ForEach(summary.exercises) { exercise in
                    Section {
                        ForEach(exercise.sets) { set in
                            VStack(alignment: .leading) {
                                Label("Set \(set.number) completed", systemImage: "checkmark.circle")
                                if set.performance.secondSideSegments != nil { Text("First side").font(.caption) }
                                ForEach(set.performance.segments.indices, id: \.self) { i in
                                    switch set.performance.segments[i] {
                                    case .toFailure: Text("To failure · Reps unspecified")
                                    case .seconds(let seconds):
                                        if set.performance.perSide && set.performance.secondSideSegments == nil {
                                            Text(
                                                "\(TrainingDisplayFormat.duration(seconds: seconds, locale: locale)) per side"
                                            )
                                        } else {
                                            Text(
                                                verbatim: TrainingDisplayFormat.duration(
                                                    seconds: seconds, locale: locale))
                                        }
                                    case .repetitions(let count):
                                        if set.performance.perSide {
                                            Text("\(count) reps per side")
                                        } else {
                                            Text("\(count) reps")
                                        }
                                    }
                                }
                                if let second = set.performance.secondSideSegments {
                                    Text("Second side").font(.caption)
                                    ForEach(second.indices, id: \.self) { index in
                                        if case .seconds(let seconds) = second[index] {
                                            Text(
                                                verbatim: TrainingDisplayFormat.duration(
                                                    seconds: seconds, locale: locale))
                                        }
                                    }
                                }
                                if let load = set.performance.load {
                                    Text(verbatim: TrainingDisplayFormat.load(load, locale: locale))
                                    Text(load.representation.title).font(.caption)
                                    if load.representation == .perImplement
                                        || (load.representation == .combined && load.implementCount > 1)
                                    {
                                        LabeledContent(
                                            "Dumbbells used",
                                            value: load.implementCount.formatted(.number.locale(locale)))
                                    }
                                }
                            }
                        }
                        if exercise.unperformed > 0 { Text("Unperformed sets: \(exercise.unperformed)") }
                        if let effort = exercise.effort {
                            Text(effort == .easy ? "Easy" : "Hard")
                        } else if !exercise.sets.isEmpty {
                            Menu("Rate exercise") {
                                Button("Easy") { rate(exercise.id, .easy) }
                                Button("Hard") { rate(exercise.id, .hard) }
                            }
                        }
                    } header: {
                        Text(verbatim: exercise.prescription.name)
                    }
                }
            }
            .onChange(of: scenePhase, initial: true) {
                guard scenePhase == .active else { return }
                do { try TrainingStorage.openStore().acknowledgeWorkoutSummary(id: summary.id) } catch { failed = true }
            }
            .navigationTitle("Workout summary")
            .toolbar { Button("Done", action: close) }
            .alert("Could not update workout", isPresented: $failed) { Button("OK") {} }
        }
    }

    private func rate(_ exerciseID: UUID, _ effort: Effort) {
        do {
            let store = try TrainingStorage.openStore()
            _ = try store.apply(
                SessionCommand(sessionID: summary.id, action: .rateFinished(exerciseID: exerciseID, effort: effort)),
                clock: SystemWorkoutClock())
            summary = try store.workoutSummary(id: summary.id)
        } catch { failed = true }
    }
}

struct WorkoutSetHeader: View {
    let name: String
    let number: Int
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: name).font(.title2.bold()).accessibilityIdentifier("workoutSetName")
            Text("Set \(number) of \(count)").font(.subheadline).foregroundStyle(.secondary)
        }
    }
}

struct WorkoutRestCountdown: View {
    @Environment(\.locale) private var locale
    let remaining: TimeInterval

    var body: some View {
        let duration = Duration.seconds(max(0, ceil(remaining)))
        Text(verbatim: duration.formatted(.time(pattern: .minuteSecond).locale(locale)))
            .font(.largeTitle.monospacedDigit().bold())
            .accessibilityLabel(Text("Rest remaining"))
            .accessibilityValue(Text(verbatim: duration.formatted(.units().locale(locale))))
    }
}

private struct WorkoutSetPrescription: View {
    @Environment(\.locale) private var locale
    let exercise: ExercisePrescription
    let equipment: EquipmentDescription?
    let gymID: UUID

    var body: some View {
        if let variant = exercise.variant {
            LabeledContent("Variant", value: variant)
        }
        LabeledContent("Prescription") {
            VStack(alignment: .trailing) {
                Text(verbatim: exercise.segments.map(segmentLabel).joined(separator: " + "))
                if exercise.perSide { Text("Per side").font(.caption) }
            }
            .multilineTextAlignment(.trailing)
        }
        LabeledContent("Load") {
            if let load = exercise.load.value {
                VStack(alignment: .trailing) {
                    Text(verbatim: TrainingDisplayFormat.load(load, locale: locale))
                    Text(load.representation.title).font(.caption)
                    if case .estimated = exercise.load { Text("Estimated load").font(.caption) }
                }
            } else {
                Text("Undefined")
            }
        }
        if let station = exercise.station ?? equipment?.station {
            LabeledContent("Station", value: station)
        }
        LabeledContent("Equipment") {
            if let equipment {
                if equipment.isGeneric(in: gymID) {
                    Text(equipment.kind.title)
                } else {
                    Text(verbatim: equipment.name)
                }
            } else {
                Text("None")
            }
        }
        if let color = exercise.bandColor {
            LabeledContent("Band color") { BandColorLabel(color: color) }
        }
        if let instructions = exercise.instructions {
            LabeledContent("Instructions", value: instructions)
        }
    }

    private func segmentLabel(_ segment: ExerciseSegment) -> String {
        switch segment {
        case .repetitions(let count): String(localized: "\(count) reps", locale: locale)
        case .seconds(let count): TrainingDisplayFormat.duration(seconds: count, locale: locale)
        case .toFailure: String(localized: TrainingDisplayFormat.toFailure(locale: locale))
        }
    }
}

private struct SetCorrectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    let record: OpenWorkout.Rest
    let save: (SetPerformance) throws -> Void
    @State private var values: [String] = []
    @State private var secondSide: [String] = []
    @State private var weight = ""
    @State private var failed = false

    var body: some View {
        NavigationStack {
            Form {
                if !secondSide.isEmpty { Text("First side") }
                ForEach(values.indices, id: \.self) { index in
                    let seconds = if case .seconds = record.prescribedSegments[index] { true } else { false }
                    if seconds {
                        durationCorrection($values[index])
                    } else {
                        TextField("Actual repetitions", text: $values[index]).keyboardType(.numberPad)
                    }
                }
                if !secondSide.isEmpty {
                    Text("Second side")
                    ForEach(secondSide.indices, id: \.self) { index in
                        durationCorrection($secondSide[index])
                    }
                }
                if record.prescribedSegments.contains(.toFailure) {
                    Text("Leave repetitions blank if you did not count them.")
                }
                if record.performance.perSide && secondSide.isEmpty { Text("Enter repetitions per side.") }
                if let load = record.performance.load {
                    LabeledContent(load.unit.rawValue) {
                        TextField("Actual load", text: $weight).keyboardType(.decimalPad)
                    }
                }
            }
            .navigationTitle("Correct set")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let corrected else { return }
                        do {
                            try save(corrected)
                            dismiss()
                        } catch { failed = true }
                    }.disabled(corrected == nil)
                }
            }
            .alert("Could not update workout", isPresented: $failed) { Button("OK") {} }
            .onAppear {
                values = record.performance.segments.map {
                    switch $0 {
                    case .toFailure: ""
                    case .seconds(let n), .repetitions(let n): String(n)
                    }
                }
                if record.performance.perSide,
                    record.prescribedSegments.allSatisfy({ if case .seconds = $0 { true } else { false } })
                {
                    secondSide =
                        record.performance.secondSideSegments?.compactMap {
                            if case .seconds(let seconds) = $0 { String(seconds) } else { nil }
                        } ?? values
                }
                if let load = record.performance.load {
                    weight = TrainingDisplayFormat.editableWeight(load.amount, locale: locale)
                }
            }
        }
    }

    private func durationCorrection(_ text: Binding<String>) -> some View {
        DurationPicker(
            "Duration", seconds: Binding(get: { Int(text.wrappedValue) ?? 0 }, set: { text.wrappedValue = String($0) }),
            range: 0...3600)
    }

    private var corrected: SetPerformance? {
        var result = record.performance
        guard values.count == record.prescribedSegments.count else { return nil }
        result.segments = []
        for (value, prescribed) in zip(values, record.prescribedSegments) {
            if value.isEmpty && prescribed == .toFailure {
                result.segments.append(.toFailure)
                continue
            }
            guard let n = Int(value) else { return nil }
            if case .seconds = prescribed {
                guard n >= 0 else { return nil }
                result.segments.append(.seconds(n))
            } else {
                guard n > 0 else { return nil }
                result.segments.append(.repetitions(n))
            }
        }
        if !secondSide.isEmpty {
            let seconds = secondSide.compactMap(Int.init)
            guard seconds.count == values.count, seconds.allSatisfy({ $0 >= 0 }) else { return nil }
            let segments = seconds.map(ExerciseSegment.seconds)
            result.secondSideSegments = segments == result.segments ? nil : segments
        }
        result.updateTimedCompletion(prescribed: record.prescribedSegments)
        if result.load != nil {
            guard let amount = TrainingDisplayFormat.parseWeight(weight, locale: locale) else { return nil }
            result.load?.amount = amount
        }
        return result
    }
}

private struct WorkoutAdjustmentView: View {
    @Environment(\.dismiss) private var dismiss
    @State var exercise: ExercisePrescription
    let workout: OpenWorkout
    let save: (SessionCommand.Action) throws -> Void
    @State private var canSaveAsUsual = false
    @State private var previous: ExercisePrescription?
    @State private var gym: GymProfile?
    @State private var usual = false
    @State private var failed = false

    var body: some View {
        NavigationStack {
            Form {
                if let previous {
                    Button("Reuse previous adjustment") {
                        exercise.sets = previous.sets
                        exercise.segments = previous.segments
                        exercise.load = previous.load
                    }
                }
                Stepper(
                    "Sets: \(exercise.sets ?? 1)",
                    value: Binding(get: { exercise.sets ?? 1 }, set: { exercise.sets = $0 }), in: 1...Int.max)
                ForEach(exercise.segments.indices, id: \.self) { index in
                    switch exercise.segments[index] {
                    case .toFailure: Text("To failure")
                    case .seconds(let count):
                        DurationPicker(
                            "Duration",
                            seconds: Binding(get: { count }, set: { exercise.segments[index] = .seconds($0) }),
                            range: 1...3600)
                    case .repetitions(let count):
                        Stepper(
                            "\(count) reps",
                            value: Binding(get: { count }, set: { exercise.segments[index] = .repetitions($0) }),
                            in: 1...Int.max)
                    }
                }
                if let gym, let equipment = gym.equipment(withID: exercise.equipmentID) {
                    NavigationLink("Load") { ExerciseLoadEditor(load: $exercise.load, gym: gym, equipment: equipment) }
                }
                if canSaveAsUsual { Toggle("Save as usual", isOn: $usual) }
            }
            .navigationTitle("Adjust exercise")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do {
                            try save(
                                .adjust(
                                    exerciseID: exercise.id, sets: exercise.sets ?? 1, segments: exercise.segments,
                                    load: exercise.load, saveAsUsual: usual))
                            dismiss()
                        } catch { failed = true }
                    }
                }
            }
            .task {
                do {
                    let store = try TrainingStorage.openStore()
                    gym = try store.gymCatalog().gyms.first { $0.id == workout.prescription.gymID }
                    let routine = try store.routine(id: workout.prescription.routineID)
                    canSaveAsUsual =
                        routine?.plan.days.first { $0.id == workout.prescription.day.id }?.exercises.contains {
                            $0.id == exercise.id
                        } == true
                    previous = try store.previousAdjustment(for: exercise.id, in: workout.prescription.routineID)
                } catch { failed = true }
            }
            .alert("Could not update workout", isPresented: $failed) { Button("OK") {} }
        }
    }
}

private struct WorkoutExerciseList: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    let workout: OpenWorkout
    let apply: (SessionCommand.Action) throws -> Void
    @State private var plan: RoutinePlan?
    @State private var usual = false
    @State private var failed = false

    var body: some View {
        NavigationStack {
            List {
                SessionExerciseRows(workout: workout, apply: run)
                NavigationLink("Add exercise") { catalog(replacing: nil) }
                if workout.pendingExercises.filter({ $0.supersetID == nil }).count >= 2
                    || workout.pendingExercises.contains(where: { $0.supersetID != nil })
                {
                    NavigationLink("Supersets") {
                        SupersetEditor(
                            day: workout.prescription.day, available: workout.pendingExercises,
                            defaultSets: plan?.defaultSets ?? 1, roundRest: workout.prescription.restBetweenSets,
                            finalRest: workout.prescription.restBetweenExercises, isWorkout: true,
                            usualDay: plan?.days.first { $0.id == workout.prescription.day.id }
                        ) { edit, usual in
                            try apply(.editSuperset(edit, saveAsUsual: usual))
                            dismiss()
                        }
                    }
                }
                if let next = workout.nextSet {
                    NavigationLink("Replace exercise") { catalog(replacing: next.exercise.id) }
                }
            }
            .navigationTitle("Exercises")
            .toolbar { Button("Close") { dismiss() } }
            .task {
                do { plan = try TrainingStorage.openStore().routine(id: workout.prescription.routineID)?.plan } catch {
                    failed = true
                }
            }
            .alert("Could not update workout", isPresented: $failed) { Button("OK") {} }
        }
    }

    private func sections(_ exercises: [ExercisePrescription]) -> [ExerciseGroupSection] {
        ExerciseGroupSection.sections(for: RoutineDay(name: "", exercises: exercises))
    }

    private func catalog(replacing: UUID?) -> some View {
        List {
            Toggle("Save as usual", isOn: $usual)
            ForEach(sections(plan?.days.flatMap(\.exercises) ?? [])) { group in
                Section {
                    ForEach(group.exercises) { exercise in
                        Button {
                            run(.insertExercise(sourceID: exercise.id, replacing: replacing, saveAsUsual: usual))
                        } label: {
                            Text(verbatim: exercise.name)
                        }
                    }
                } header: {
                    if let heading = group.heading(locale: locale) { Text(verbatim: heading) }
                }
            }
        }
    }

    private func run(_ action: SessionCommand.Action) {
        do {
            try apply(action)
            dismiss()
        } catch { failed = true }
    }
}
