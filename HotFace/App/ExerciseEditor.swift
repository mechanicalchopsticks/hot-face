import SwiftUI
import TrainingDomain
import TrainingInterface
import TrainingRepositories

struct ExerciseEditor: View {
    @Binding var day: RoutineDay
    @Binding var exercise: ExercisePrescription
    let gym: GymProfile
    let defaults: RoutinePlan
    let history: GymLoadHistory?
    @Environment(\.locale) private var locale
    @State private var creatingGroup = false
    @State private var groupName = ""

    var body: some View {
        Form {
            Section {
                TextField("Exercise name", text: $exercise.name)
                Picker(
                    "Exercise group",
                    selection: Binding(get: { exercise.group }, set: { day.assignGroup($0, to: exercise.id) })
                ) {
                    Text("No group").tag(nil as String?)
                    ForEach(day.groupNames, id: \.self) { Text(verbatim: $0).tag(Optional($0)) }
                }
                Button("Create group…") {
                    groupName = ""
                    creatingGroup = true
                }
                TextField("Variant (optional)", text: text($exercise.variant))
                TextField("Instructions (optional)", text: text($exercise.instructions), axis: .vertical)
                TextField("Station (optional)", text: text($exercise.station))
            }
            Section("Prescription") {
                Toggle(
                    "Custom set count",
                    isOn: Binding(
                        get: { exercise.sets != nil },
                        set: { exercise.sets = $0 ? defaults.setCount(for: exercise) : nil }))
                if exercise.sets != nil {
                    Stepper(
                        "Sets: \(defaults.setCount(for: exercise))",
                        value: Binding(get: { defaults.setCount(for: exercise) }, set: { exercise.sets = $0 }),
                        in: 1...Int.max)
                } else {
                    Text("Sets: \(defaults.setCount(for: exercise))")
                }
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
                let assigned = gym.equipment(withID: exercise.equipmentID)
                if exercise.equipmentID != nil && assigned == nil {
                    Label(
                        "Assigned equipment was deleted. Choose a replacement.", systemImage: "exclamationmark.triangle"
                    )
                }
                Picker(
                    "Equipment",
                    selection: Binding(
                        get: { assigned?.id },
                        set: { id in
                            guard exercise.equipmentID != id else { return }
                            exercise.equipmentID = id
                            exercise.load = .undefined
                            if gym.equipment(withID: id)?.kind != .band { exercise.bandColor = nil }
                        })
                ) {
                    Text("None").tag(nil as UUID?)
                    Section("Generic equipment") {
                        ForEach(gym.genericEquipment) { Text($0.kind.title).tag(Optional($0.id)) }
                    }
                    if !gym.equipment.isEmpty {
                        Section("Specific equipment") {
                            ForEach(gym.equipment) { Text(verbatim: $0.name).tag(Optional($0.id)) }
                        }
                    }
                }
                if assigned?.kind == .band {
                    NavigationLink {
                        BandColorPicker(selection: $exercise.bandColor)
                    } label: {
                        LabeledContent("Band color") { BandColorLabel(color: exercise.bandColor) }
                    }
                }
                if let equipment = assigned,
                    equipment.kind != .band || !equipment.availableLoads.isEmpty || exercise.load.value != nil
                {
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
                } else if let current = exercise.load.value {
                    LabeledContent("Usual load", value: TrainingDisplayFormat.load(current, locale: locale))
                    Button("Clear load") { exercise.load = .undefined }
                }
                if let previous = history?.suggestion(for: exercise) {
                    NavigationLink("Review previous load") {
                        HistoricalLoadReview(
                            previous: previous, exercise: $exercise, sets: defaults.setCount(for: exercise),
                            locale: locale)
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
        .alert("Create group", isPresented: $creatingGroup) {
            TextField("Group name", text: $groupName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                if !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    day.assignGroup(groupName, to: exercise.id)
                }
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

private struct BandColorPicker: View {
    @Binding var selection: ResistanceBandColor?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            option(nil)
            ForEach(ResistanceBandColor.allCases, id: \.self) { option($0) }
        }
        .navigationTitle("Band color")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func option(_ color: ResistanceBandColor?) -> some View {
        Button {
            selection = color
            dismiss()
        } label: {
            HStack {
                BandColorLabel(color: color).foregroundStyle(.primary)
                Spacer()
                if color == selection { Image(systemName: "checkmark").accessibilityHidden(true) }
            }
        }
        .accessibilityAddTraits(color == selection ? .isSelected : [])
    }
}

private struct BandColorLabel: View {
    let color: ResistanceBandColor?

    var body: some View {
        if let color {
            HStack {
                Circle()
                    .fill(color.swatch)
                    .overlay { Circle().strokeBorder(.secondary, lineWidth: 1) }
                    .frame(width: 18, height: 18)
                    .accessibilityHidden(true)
                Text(color.title)
            }
        } else {
            Text("No band selected")
        }
    }
}

extension ResistanceBandColor {
    fileprivate var title: LocalizedStringKey {
        switch self {
        case .red: "Red"
        case .orange: "Orange"
        case .yellow: "Yellow"
        case .green: "Green"
        case .blue: "Blue"
        case .purple: "Purple"
        case .brown: "Brown"
        case .pink: "Pink"
        case .lightBlue: "Light blue"
        case .white: "White"
        case .lightGray: "Light gray"
        case .darkGray: "Dark gray"
        case .black: "Black"
        }
    }

    fileprivate var swatch: Color {
        switch self {
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .blue: .blue
        case .purple: .purple
        case .brown: .brown
        case .pink: Color(red: 1, green: 0.55, blue: 0.75)
        case .lightBlue: Color(red: 0.38, green: 0.75, blue: 0.95)
        case .white: .white
        case .lightGray: Color(white: 0.78)
        case .darkGray: Color(white: 0.30)
        case .black: .black
        }
    }
}

private struct HistoricalLoadReview: View {
    @Environment(\.dismiss) private var dismiss
    let previous: HistoricalLoad
    @Binding var exercise: ExercisePrescription
    let sets: Int
    let locale: Locale
    @State private var amount: String

    init(previous: HistoricalLoad, exercise: Binding<ExercisePrescription>, sets: Int, locale: Locale) {
        self.previous = previous
        self._exercise = exercise
        self.sets = sets
        self.locale = locale
        _amount = State(initialValue: TrainingDisplayFormat.editableWeight(previous.load.amount, locale: locale))
    }

    var body: some View {
        Form {
            Section("Previous workout") {
                LabeledContent("Date", value: TrainingDisplayFormat.date(previous.performedAt, locale: locale))
                LabeledContent(
                    "Prescription",
                    value: TrainingDisplayFormat.prescription(
                        previous.exercise, sets: previous.exercise.sets ?? 1, locale: locale))
                if previous.exercise.perSide { Text("Per side") }
                LabeledContent(
                    previous.load.representation.title, value: TrainingDisplayFormat.load(previous.load, locale: locale)
                )
                if let station = previous.station { LabeledContent("Station", value: station) }
                if let instructions = previous.exercise.instructions {
                    LabeledContent("Instructions", value: instructions)
                }
            }
            Section("New prescription") {
                Text(verbatim: TrainingDisplayFormat.prescription(exercise, sets: sets, locale: locale))
                if exercise.perSide { Text("Per side") }
                HStack {
                    TextField("Weight", text: $amount).keyboardType(.decimalPad)
                    Text(verbatim: previous.load.unit.rawValue)
                }
                let weight = TrainingDisplayFormat.parseWeight(amount, locale: locale)
                Button("Confirm load") {
                    if let weight {
                        exercise.load = previous.confirmed(amount: weight)
                        dismiss()
                    }
                }.disabled(weight == nil)
                Button("Leave undefined") { dismiss() }
            }
        }.navigationTitle("Review previous load")
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
