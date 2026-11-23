import SwiftUI
import TrainingDomain
import TrainingInterface

struct SampleWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    private let controller = SampleWorkoutController.shared
    @State private var showsLiveActivity = true
    @State private var editingSet: SampleWorkout.CompletedSet?

    private var session: SampleWorkout { controller.session }

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
                            Button("Finish workout") { controller.finish() }
                        } label: {
                            Label("More", systemImage: "ellipsis.circle")
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { primaryAction }
            .sheet(item: $editingSet) { record in
                SampleSetCorrectionView(record: record) { performance in
                    controller.correct(record, with: performance)
                }
            }
        }
    }

    @ViewBuilder
    private var intro: some View {
        Section {
            Toggle("Show on Lock Screen", isOn: $showsLiveActivity)
        }
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
        } footer: {
            if controller.liveActivityUnavailable { Text("Lock Screen controls are unavailable.") }
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
            case .ready: action("Start day") { controller.start(showsLiveActivity: showsLiveActivity) }
            case .set: action("Complete set") { controller.completeSet() }
            case .rest:
                action(session.continuesExercise ? "Next set" : "Next exercise") { controller.advance() }
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
