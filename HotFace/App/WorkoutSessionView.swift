import SwiftUI
import TrainingAdapters
import TrainingDomain
import TrainingInterface
import TrainingRepositories

struct WorkoutSessionView: View {
    @EnvironmentObject private var audio: HoldAudioDelegate
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State var workout: OpenWorkout
    @State private var actionError: LocalizedStringKey?
    @State private var confirmsFinish = false

    @State private var correcting: OpenWorkout.Rest?

    @State private var adjusting: ExercisePrescription?

    @State private var choosingExercise = false

    @State private var summary: WorkoutSummary?

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
        return NavigationStack {
            List {
                if let rest {
                    Section {
                        WorkoutRestCountdown(remaining: rest.endsAt.timeIntervalSince(date))
                        HStack {
                            Button("−15 s") { adjustRest(rest, by: .shorten) }
                                .accessibilityLabel("Shorten rest by 15 seconds")
                            Spacer()
                            Button("+15 s") { adjustRest(rest, by: .extend) }
                                .accessibilityLabel("Extend rest by 15 seconds")
                        }
                        .buttonStyle(.bordered)
                        Button("Correct set") { correcting = rest }
                        Label("Set \(rest.completedSetNumber) completed", systemImage: "checkmark.circle")
                    } header: {
                        Text("Rest")
                    }
                }
                if let set = workout.nextSet {
                    Section {
                        WorkoutSetHeader(name: set.exercise.name, number: set.number, count: set.count)
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
                        if rest != nil { Text("Up next") } else if workout.timer == nil { Text("Ready") }
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
                            Button("Finish workout") { confirmsFinish = true }
                        } label: {
                            Label("More", systemImage: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $choosingExercise) {
                WorkoutExerciseList(workout: workout) { action in try apply(action) }
            }
            .sheet(item: $adjusting) { exercise in
                WorkoutAdjustmentView(exercise: exercise, workout: workout) { action in try apply(action) }
            }
            .sheet(item: $correcting) { record in
                SetCorrectionView(record: record) { performance in
                    try apply(.correctSet(id: record.id, performance: performance))
                }
            }
            .safeAreaInset(edge: .bottom) { primaryAction(rest: rest, at: date) }
            .onChange(of: scenePhase, initial: true) {
                if scenePhase == .active { refresh() }
            }
            .task(id: workout.timer?.exerciseEnd) {
                guard let end = workout.timer?.exerciseEnd else { return }
                try? await Task.sleep(for: .seconds(max(0, end.timeIntervalSinceNow)))
                if !Task.isCancelled { refresh() }
            }
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
                    action("Start set") { control(.start, set: set, revision: 0) }
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

    private func refresh() {
        do { try reload(from: TrainingStorage.openStore()) } catch { actionError = "Could not update workout" }
    }

    private func reload(from store: CoordinatedModelStore) throws {
        if let updated = try store.openWorkout(), updated.id == workout.id {
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
            audio.schedule(summary == nil ? workout.timingCues : [])
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
            try apply(
                .logSet(exerciseID: set.exercise.id, number: set.number, performance: .init(asPrescribed: set.exercise))
            )
        } catch { actionError = "Could not update workout" }
    }

    private func adjustRest(_ rest: OpenWorkout.Rest, by adjustment: RestAdjustment) {
        do { try apply(.adjustRest(setID: rest.id, adjustment: adjustment)) } catch SessionCommandError.restUnavailable
        {} catch { actionError = "Could not update workout" }
    }

    private func finish() {
        do {
            try apply(.finish)
            audio.schedule([])
        } catch { actionError = "Could not finish workout" }
    }
}

struct FinishedWorkoutView: View {
    @State var summary: WorkoutSummary
    let close: () -> Void
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
                                            Text("\(seconds) s per side")
                                        } else {
                                            Text("\(seconds) s")
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
                                        if case .seconds(let seconds) = second[index] { Text("\(seconds) s") }
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
            Text(verbatim: name).font(.title2.bold())
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
        case .seconds(let count): String(localized: "\(count) s", locale: locale)
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
                    TextField(seconds ? "Seconds" : "Actual repetitions", text: $values[index]).keyboardType(.numberPad)
                }
                if !secondSide.isEmpty {
                    Text("Second side")
                    ForEach(secondSide.indices, id: \.self) { index in
                        TextField("Seconds", text: $secondSide[index]).keyboardType(.numberPad)
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
                    case .seconds(let count), .repetitions(let count):
                        let seconds = exercise.segments[index] == .seconds(count)
                        Stepper(
                            value: Binding(
                                get: { count },
                                set: { exercise.segments[index] = seconds ? .seconds($0) : .repetitions($0) }),
                            in: 1...Int.max
                        ) {
                            if seconds { Text("\(count) s") } else { Text("\(count) reps") }
                        }
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
                ForEach(sections(workout.pendingExercises)) { group in
                    Section {
                        ForEach(group.exercises) { exercise in
                            Menu {
                                Button("Select exercise") { run(.moveExercise(id: exercise.id, toFront: true)) }
                                Button("Postpone exercise") { run(.moveExercise(id: exercise.id, toFront: false)) }
                                Button("Skip exercise") { run(.skipAndAdvance(exerciseID: exercise.id)) }
                            } label: {
                                Text(verbatim: exercise.name)
                            }
                        }
                    } header: {
                        if let heading = group.heading(locale: locale) { Text(verbatim: heading) }
                    }
                }
                NavigationLink("Add exercise") { catalog(replacing: nil) }
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
