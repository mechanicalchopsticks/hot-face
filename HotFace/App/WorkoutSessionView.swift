import SwiftUI
import TrainingAdapters
import TrainingDomain
import TrainingInterface
import TrainingRepositories

struct WorkoutSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @State var workout: OpenWorkout
    @State private var reviewedRestID: UUID?
    @State private var actionError: LocalizedStringKey?
    @State private var confirmsFinish = false

    @State private var correcting: OpenWorkout.Rest?

    private var rest: OpenWorkout.Rest? {
        workout.rest.flatMap { $0.id == reviewedRestID ? nil : $0 }
    }

    var body: some View {
        NavigationStack {
            List {
                if let rest {
                    Section {
                        WorkoutRestCountdown(end: rest.endsAt)
                        Button("Correct set") { correcting = rest }
                        Label("Set \(rest.completedSetNumber) completed", systemImage: "checkmark.circle")
                    } header: {
                        Text("Rest")
                    }
                }
                if let set = workout.nextSet {
                    Section {
                        WorkoutSetHeader(name: set.exercise.name, number: set.number, count: set.count)
                        WorkoutSetPrescription(
                            exercise: set.exercise, equipment: set.equipment, gymID: workout.prescription.gymID)
                    } header: {
                        if rest != nil { Text("Up next") }
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
                            Button("Finish workout") { confirmsFinish = true }
                        } label: {
                            Label("More", systemImage: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(item: $correcting) { record in
                SetCorrectionView(record: record) { performance in
                    let store = try TrainingStorage.openStore()
                    _ = try store.apply(
                        SessionCommand(
                            sessionID: workout.id, action: .correctSet(id: record.id, performance: performance)),
                        clock: SystemWorkoutClock())
                    if let updated = try store.openWorkout(), updated.id == workout.id { workout = updated }
                }
            }
            .safeAreaInset(edge: .bottom) { primaryAction }
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

    private var primaryAction: some View {
        Group {
            if let rest {
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    action(rest.betweenExercises ? "Next exercise" : "Next set") { reviewedRestID = rest.id }
                        .disabled(timeline.date < rest.endsAt)
                }
            } else if let set = workout.nextSet {
                action("Complete set") { complete(set) }
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

    private func complete(_ set: OpenWorkout.PendingSet) {
        do {
            let store = try TrainingStorage.openStore()
            _ = try store.apply(
                SessionCommand(
                    sessionID: workout.id,
                    action: .completeSet(
                        exerciseID: set.exercise.id, number: set.number,
                        performance: SetPerformance(asPrescribed: set.exercise))),
                clock: SystemWorkoutClock())
            if let updated = try store.openWorkout(), updated.id == workout.id {
                workout = updated
            } else {
                dismiss()
            }
        } catch {
            actionError = "Could not update workout"
        }
    }

    private func finish() {
        do {
            _ = try TrainingStorage.openStore().apply(
                SessionCommand(sessionID: workout.id, action: .finish), clock: SystemWorkoutClock())
            dismiss()
        } catch {
            actionError = "Could not finish workout"
        }
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
    let end: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let remaining = max(0, ceil(end.timeIntervalSince(timeline.date)))
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
    @State private var weight = ""
    @State private var failed = false

    var body: some View {
        NavigationStack {
            Form {
                ForEach(values.indices, id: \.self) { index in
                    let seconds = if case .seconds = record.exercise.segments[index] { true } else { false }
                    TextField(seconds ? "Seconds" : "Actual repetitions", text: $values[index]).keyboardType(.numberPad)
                }
                if record.exercise.segments.contains(.toFailure) {
                    Text("Leave repetitions blank if you did not count them.")
                }
                if record.performance.perSide { Text("Enter repetitions per side.") }
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
                if let load = record.performance.load {
                    weight = TrainingDisplayFormat.editableWeight(load.amount, locale: locale)
                }
            }
        }
    }

    private var corrected: SetPerformance? {
        var result = record.performance
        guard values.count == record.exercise.segments.count else { return nil }
        result.segments = []
        for (value, prescribed) in zip(values, record.exercise.segments) {
            if value.isEmpty && prescribed == .toFailure {
                result.segments.append(.toFailure)
                continue
            }
            guard let n = Int(value), n > 0 else { return nil }
            if case .seconds = prescribed {
                result.segments.append(.seconds(n))
            } else {
                result.segments.append(.repetitions(n))
            }
        }
        if result.load != nil {
            guard let amount = TrainingDisplayFormat.parseWeight(weight, locale: locale) else { return nil }
            result.load?.amount = amount
        }
        return result
    }
}
