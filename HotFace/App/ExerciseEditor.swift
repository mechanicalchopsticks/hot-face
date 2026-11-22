import SwiftUI
import TrainingDomain
import TrainingInterface
import TrainingRepositories

struct ExerciseEditor: View {
    @Binding var exercise: ExercisePrescription
    let gym: GymProfile
    let defaults: RoutinePlan
    @Environment(\.locale) private var locale

    var body: some View {
        Form {
            Section {
                TextField("Exercise name", text: $exercise.name)
                TextField("Group (optional)", text: text($exercise.group))
                TextField("Variant (optional)", text: text($exercise.variant))
                TextField("Instructions (optional)", text: text($exercise.instructions), axis: .vertical)
                TextField("Station (optional)", text: text($exercise.station))
            }
            Section("Prescription") {
                Stepper("Sets: \(exercise.sets)", value: $exercise.sets, in: 1...Int.max)
                Toggle("Per side", isOn: $exercise.perSide)
            }
            Section("Segments in each set") {
                ForEach(exercise.segments.indices, id: \.self) { index in
                    segmentRow(index)
                }
                .onDelete { exercise.segments.remove(atOffsets: $0) }
                .onMove { exercise.segments.move(fromOffsets: $0, toOffset: $1) }
                Button("Add segment", systemImage: "plus") {
                    exercise.segments.append(exercise.segments.last ?? .repetitions(8))
                }
            }
            Section("Equipment and load") {
                Picker(
                    "Equipment",
                    selection: Binding(
                        get: { exercise.equipmentID },
                        set: { id in
                            guard exercise.equipmentID != id else { return }
                            exercise.equipmentID = id
                            exercise.load = .undefined
                        })
                ) {
                    Text("None").tag(nil as UUID?)
                    ForEach(gym.equipment) { Text(verbatim: $0.name).tag(Optional($0.id)) }
                }
                if let equipment = gym.equipment.first(where: { $0.id == exercise.equipmentID }) {
                    NavigationLink {
                        ExerciseLoadEditor(load: $exercise.load, gym: gym, equipment: equipment)
                    } label: {
                        LabeledContent("Usual load") {
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
                    }
                }
            }
            Section("Exercise rest") {
                optionalRest(
                    "Custom rest between sets", title: "Between sets", value: $exercise.restBetweenSets,
                    inherited: defaults.restBetweenSets)
                optionalRest(
                    "Custom rest after exercise", title: "After exercise", value: $exercise.restAfterExercise,
                    inherited: defaults.restBetweenExercises)
            }
        }
        .navigationTitle("Edit exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
    }

    private func text(_ value: Binding<String?>) -> Binding<String> {
        Binding(get: { value.wrappedValue ?? "" }, set: { value.wrappedValue = $0.isEmpty ? nil : $0 })
    }

    private func segmentRow(_ index: Int) -> some View {
        let segment = exercise.segments[index]
        let timed: Bool
        let quantity: Int
        switch segment {
        case .repetitions(let count):
            timed = false
            quantity = count
        case .seconds(let seconds):
            timed = true
            quantity = seconds
        }
        return VStack {
            Picker(
                "Segment type",
                selection: Binding(
                    get: { timed },
                    set: { isTimed in
                        exercise.segments[index] = isTimed ? .seconds(quantity) : .repetitions(quantity)
                    })
            ) {
                Text("Repetitions").tag(false)
                Text("Seconds").tag(true)
            }.pickerStyle(.segmented)
            Stepper(
                value: Binding(
                    get: { quantity },
                    set: { newValue in
                        exercise.segments[index] = timed ? .seconds(newValue) : .repetitions(newValue)
                    }), in: 1...Int.max
            ) {
                if timed { Text("\(quantity) s") } else { Text("Reps: \(quantity)") }
            }
        }
    }

    @ViewBuilder
    private func optionalRest(
        _ toggle: LocalizedStringKey, title: LocalizedStringKey, value: Binding<TimeInterval?>,
        inherited: TimeInterval
    ) -> some View {
        Toggle(
            toggle,
            isOn: Binding(get: { value.wrappedValue != nil }, set: { value.wrappedValue = $0 ? inherited : nil }))
        if value.wrappedValue != nil {
            RestStepper(
                title: title,
                seconds: Binding(get: { value.wrappedValue ?? inherited }, set: { value.wrappedValue = $0 }))
        }
    }
}

struct RestStepper: View {
    let title: LocalizedStringKey
    @Binding var seconds: TimeInterval

    var body: some View {
        Stepper(value: $seconds, in: 0...TimeInterval.greatestFiniteMagnitude, step: 1) {
            LabeledContent(title) { Text("\(seconds.formatted(.number)) s") }
        }
    }
}
