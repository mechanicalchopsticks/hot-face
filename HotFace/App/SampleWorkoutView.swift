import SwiftUI
import TrainingDomain
import TrainingInterface

struct SampleWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var session = SampleWorkout()
    @State private var editingSet: SampleWorkout.CompletedSet?

    var body: some View {
        NavigationStack {
            List {
                switch session.phase {
                case .ready:
                    intro
                case .set, .rest:
                    if let current = session.currentSet {
                        if case .rest(let end) = session.phase, let completed = session.completed.last {
                            rest(until: end, after: completed)
                        }
                        exercise(current)
                    }
                case .summary:
                    summary
                }
            }
            .navigationTitle("Sample workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if session.phase == .set || session.isResting {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button("Finish workout") { session.finish() }
                        } label: {
                            Label("More", systemImage: "ellipsis.circle")
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { primaryAction }
            .sheet(item: $editingSet) { record in
                SampleSetCorrectionView(record: record) { performance in
                    session.correct(record, with: performance)
                }
            }
        }
    }

    private var intro: some View {
        Section {
            ForEach(SampleWorkout.exercises) { exercise in
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: exercise.prescription.name)
                    Text(
                        verbatim: TrainingDisplayFormat.prescription(
                            exercise.prescription, sets: exercise.setCount, locale: locale)
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Day 3")
        } footer: {
            Text("Sample loads and progress are for this walkthrough only.")
        }
    }

    private func exercise(_ current: SampleWorkout.PlannedSet) -> some View {
        let exercise = current.exercise
        let prescription = exercise.prescription
        return Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: prescription.name)
                    .font(.title2.bold())
                Text("Set \(current.number) of \(exercise.setCount)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("sample-current-set")
            }
            LabeledContent("Repetitions") {
                performanceRepetitions(SetPerformance(asPrescribed: prescription), awaitingCount: false)
            }
            if let load = prescription.load.value {
                LabeledContent("Sample load") { loadValue(load) }
            }
            if let station = prescription.station {
                LabeledContent("Station", value: station)
            }
            LabeledContent("Equipment") { Text(exercise.equipment.title) }
            if let instructions = prescription.instructions {
                LabeledContent("Instructions", value: instructions)
            }
        } header: {
            if session.isResting { Text("Up next") }
        }
    }

    private func rest(until end: Date, after record: SampleWorkout.CompletedSet) -> some View {
        Section {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                let remaining = max(0, Int(ceil(end.timeIntervalSince(timeline.date))))
                if remaining > 0 {
                    Text(verbatim: Duration.seconds(remaining).formatted(.time(pattern: .minuteSecond).locale(locale)))
                        .font(.largeTitle.monospacedDigit().bold())
                        .accessibilityLabel(Text("Rest remaining"))
                        .accessibilityValue(
                            Text(verbatim: Duration.seconds(remaining).formatted(.units().locale(locale))))
                } else {
                    Text("Rest complete").font(.title2.bold())
                }
            }
            completedSet(record)
            Button("Correct set") { editingSet = record }
        } header: {
            Text("Rest")
                .accessibilityIdentifier("sample-rest")
        }
    }

    private var summary: some View {
        Group {
            Section {
                Text("Workout summary").font(.title2.bold())
            }
            ForEach(SampleWorkout.exercises) { exercise in
                let records = session.completed.filter { $0.planned.exercise.id == exercise.id }
                if !records.isEmpty {
                    Section {
                        ForEach(records) { record in completedSet(record) }
                    } header: {
                        Text(verbatim: exercise.prescription.name)
                    }
                }
            }
        }
    }

    private func completedSet(_ record: SampleWorkout.CompletedSet) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Set \(record.planned.number) completed", systemImage: "checkmark.circle")
                .font(.headline)
            performanceRepetitions(record.performance, awaitingCount: true)
                .accessibilityIdentifier("sample-record-repetitions-\(record.id)")
            if let load = record.performance.load {
                loadValue(load)
                    .accessibilityIdentifier("sample-record-load-\(record.id)")
            }
        }
        .foregroundStyle(.primary)
    }

    private func loadValue(_ load: ExerciseLoad) -> Text {
        let value = TrainingDisplayFormat.load(load, locale: locale)
        switch load.representation {
        case .perImplement: return Text("\(value) per dumbbell")
        case .totalAdded: return Text("\(value) added")
        default: return Text(verbatim: value)
        }
    }

    private func performanceRepetitions(_ performance: SetPerformance, awaitingCount: Bool) -> Text {
        switch performance.segments.first {
        case .repetitions(let count):
            if performance.perSide { return Text("\(count) reps per side") }
            return Text("\(count) reps")
        default:
            if awaitingCount { return Text("To failure · Reps unspecified") }
            return Text(TrainingDisplayFormat.toFailure(locale: locale))
        }
    }

    private var primaryAction: some View {
        Group {
            switch session.phase {
            case .ready: action("Start day") { session.start() }
            case .set: action("Complete set") { session.completeSet(at: .now) }
            case .rest:
                action(session.continuesExercise ? "Next set" : "Next exercise") { session.advance() }
            case .summary: action("Done") { dismiss() }
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding()
        .background(.bar)
    }

    private func action(_ title: LocalizedStringKey, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Text(title)
                .frame(maxWidth: .infinity, minHeight: 32)
        }
    }
}

private struct SampleSetCorrectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    let record: SampleWorkout.CompletedSet
    let save: (SetPerformance) -> Void
    @State private var repetitions = ""
    @State private var weight = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Actual repetitions", text: $repetitions)
                        .keyboardType(.numberPad)
                    if let load = record.performance.load {
                        LabeledContent("Actual load") {
                            TextField(load.unit.rawValue, text: $weight)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .accessibilityIdentifier("sample-actual-load")
                            Text(verbatim: load.unit.rawValue)
                        }
                    }
                } footer: {
                    if isToFailure {
                        Text("Leave repetitions blank if you did not count them.")
                    } else if record.performance.perSide {
                        Text("Enter repetitions per side.")
                    }
                }
            }
            .navigationTitle("Correct set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let corrected else { return }
                        save(corrected)
                        dismiss()
                    }
                    .disabled(corrected == nil)
                }
            }
            .onAppear {
                if case .repetitions(let count) = record.performance.segments.first {
                    repetitions = count.formatted(.number.locale(locale).grouping(.never))
                }
                if let load = record.performance.load {
                    weight = TrainingDisplayFormat.editableWeight(load.amount, locale: locale)
                }
            }
        }
    }

    private var isToFailure: Bool {
        record.planned.exercise.prescription.segments == [.toFailure]
    }

    private var corrected: SetPerformance? {
        var performance = record.performance
        if repetitions.isEmpty && isToFailure {
            performance.segments = [.toFailure]
        } else {
            let format = IntegerFormatStyle<Int>(locale: locale).grouping(.never)
            guard repetitions.unicodeScalars.allSatisfy(CharacterSet.decimalDigits.contains),
                let count = try? Int(repetitions, format: format, lenient: false), count > 0
            else { return nil }
            performance.segments = [.repetitions(count)]
        }

        if performance.load != nil {
            guard let amount = TrainingDisplayFormat.parseWeight(weight, locale: locale) else { return nil }
            performance.load?.amount = amount
        }
        return performance
    }
}

private struct SampleWorkout {
    enum Phase: Equatable {
        case ready, set
        case rest(until: Date)
        case summary
    }

    struct Exercise: Identifiable {
        let prescription: ExercisePrescription
        let equipment: EquipmentDescription.Kind
        let setCount: Int

        var id: UUID { prescription.id }

        init(
            _ name: String, equipment: EquipmentDescription.Kind, segment: ExerciseSegment, sets: Int = 4,
            station: String? = nil, instructions: String? = nil, perSide: Bool = false,
            load: Int, unit: ExerciseLoad.Unit = .kg, representation: ExerciseLoad.Representation = .combined,
            implementCount: Int = 1
        ) {
            var prescription = ExercisePrescription(name: name, sets: sets, segments: [segment])
            prescription.station = station
            prescription.instructions = instructions
            prescription.perSide = perSide
            prescription.load = .estimated(
                .init(
                    amount: Decimal(load), unit: unit, representation: representation, implementCount: implementCount))
            self.prescription = prescription
            self.equipment = equipment
            self.setCount = sets
        }
    }

    struct PlannedSet {
        let exercise: Exercise
        let number: Int
    }

    struct CompletedSet: Identifiable {
        let id: Int
        let planned: PlannedSet
        var performance: SetPerformance
    }

    // Day 3 of rutina1. The first exercise uses two sets to failure for the walkthrough.
    static let exercises: [Exercise] = [
        .init(
            "Jalón polea abierto", equipment: .selectorizedMachine, segment: .toFailure, sets: 2, station: "23",
            load: 35),
        .init(
            "Remo T", equipment: .plateLoadedMachine, segment: .repetitions(10), station: "24",
            instructions: "abierto", load: 25, unit: .lb, representation: .totalAdded),
        .init(
            "Remo mancuerna", equipment: .dumbbell, segment: .repetitions(10), perSide: true,
            load: 25, unit: .lb, representation: .perImplement),
        .init("Face pulls", equipment: .selectorizedMachine, segment: .repetitions(15), station: "18", load: 15),
        .init(
            "Curl martillo", equipment: .dumbbell, segment: .repetitions(10), load: 15, unit: .lb,
            representation: .perImplement, implementCount: 2),
        .init("Curl barra", equipment: .fixedBar, segment: .repetitions(12), load: 15),
    ]

    private static let planned = exercises.flatMap { exercise in
        (1...exercise.setCount).map { PlannedSet(exercise: exercise, number: $0) }
    }

    private(set) var phase = Phase.ready
    private(set) var completed: [CompletedSet] = []

    var currentSet: PlannedSet? {
        guard Self.planned.indices.contains(completed.count) else { return nil }
        return Self.planned[completed.count]
    }

    var continuesExercise: Bool { currentSet?.number != 1 }

    var isResting: Bool {
        if case .rest = phase { return true }
        return false
    }

    mutating func start() { phase = .set }
    mutating func finish() { phase = .summary }

    mutating func completeSet(at date: Date) {
        guard phase == .set, let currentSet else { return }
        completed.append(
            .init(
                id: completed.count, planned: currentSet,
                performance: SetPerformance(asPrescribed: currentSet.exercise.prescription)))
        if self.currentSet != nil {
            let rest: TimeInterval = continuesExercise ? 105 : 135
            phase = .rest(until: date.addingTimeInterval(rest))
        } else {
            finish()
        }
    }

    mutating func correct(_ record: CompletedSet, with performance: SetPerformance) {
        guard isResting, completed.last?.id == record.id else { return }
        completed[record.id].performance = performance
    }

    mutating func advance() {
        guard isResting else { return }
        phase = .set
    }
}
