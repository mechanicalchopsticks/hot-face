import SwiftUI
import TrainingDomain
import TrainingInterface
import TrainingRepositories

struct ExerciseLoadEditor: View {
    @Binding var load: PrescribedLoad
    let gym: GymProfile
    let equipment: EquipmentDescription
    @Environment(\.locale) private var locale
    @State private var count: Int
    @State private var representation: ExerciseLoad.Representation

    init(load: Binding<PrescribedLoad>, gym: GymProfile, equipment: EquipmentDescription) {
        self._load = load
        self.gym = gym
        self.equipment = equipment
        let value = load.wrappedValue.value
        _count = State(initialValue: value?.implementCount ?? 1)
        let initial: ExerciseLoad.Representation
        switch equipment.kind {
        case .barbell, .plateLoadedMachine: initial = .perSide
        case .dumbbell: initial = .perImplement
        default: initial = .combined
        }
        _representation = State(initialValue: value?.representation ?? initial)
    }

    private var representations: [ExerciseLoad.Representation] {
        switch equipment.kind {
        case .dumbbell: [.perImplement, .combined]
        case .barbell, .plateLoadedMachine:
            equipment.baseWeight == nil ? [.perSide, .totalAdded] : [.perSide, .totalAdded, .includingEquipment]
        default: [.combined]
        }
    }

    var body: some View {
        List {
            Section {
                if equipment.kind == .dumbbell {
                    Picker("Dumbbells used", selection: Binding(get: { count }, set: changeCount)) {
                        Text("1").tag(1)
                        Text("2").tag(2)
                    }
                }
                Picker("Load representation", selection: Binding(get: { representation }, set: changeRepresentation)) {
                    ForEach(representations, id: \.self) { Text($0.title).tag($0) }
                }
                if representations.contains(.totalAdded), equipment.baseWeight == nil {
                    Text("Set the equipment’s base weight in Settings to see the total including equipment.")
                        .font(.footnote)
                }
                if let current = load.value {
                    LabeledContent("Usual load", value: TrainingDisplayFormat.load(current, locale: locale))
                    Toggle(
                        "Estimated load",
                        isOn: Binding(
                            get: {
                                if case .estimated = load { return true }
                                return false
                            }, set: { load = $0 ? .estimated(current) : .confirmed(current) }))
                }
            }
            Section("Available loads") {
                optionRow(Text("Undefined"), selected: load == .undefined) { load = .undefined }
                let options = gym.loadOptions(for: equipment.id, dumbbellCount: count)
                ForEach(options.indices, id: \.self) { index in
                    if let option = displayed(options[index], as: representation) {
                        optionRow(
                            Text(verbatim: TrainingDisplayFormat.load(option, locale: locale)),
                            selected: load.value == option
                        ) { load = .confirmed(option) }
                    }
                }
            }
        }
        .navigationTitle("Usual load")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func optionRow(_ title: Text, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                title.foregroundStyle(.primary)
                Spacer()
                if selected { Image(systemName: "checkmark") }
            }
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func displayed(_ value: ExerciseLoad, as target: ExerciseLoad.Representation) -> ExerciseLoad? {
        let base = equipment.baseWeight.map { equipment.unit.converted($0, to: value.unit) }
        return try? value.displayed(as: target, equipmentWeightInLoadUnit: base)
    }

    private func changeRepresentation(_ target: ExerciseLoad.Representation) {
        if let current = load.value {
            guard let converted = displayed(current, as: target) else { return }
            replaceValue(converted)
        }
        representation = target
    }

    private func changeCount(_ newCount: Int) {
        if let current = load.value {
            guard var individual = displayed(current, as: .perImplement) else { return }
            individual.implementCount = newCount
            guard let converted = displayed(individual, as: representation) else { return }
            replaceValue(converted)
        }
        count = newCount
    }

    private func replaceValue(_ value: ExerciseLoad) {
        if case .estimated = load { load = .estimated(value) } else { load = .confirmed(value) }
    }
}

extension ExerciseLoad.Representation {
    var title: LocalizedStringKey {
        switch self {
        case .perImplement: "Per dumbbell"
        case .combined: "Total weight"
        case .perSide: "Added per side"
        case .totalAdded: "Total added"
        case .includingEquipment: "Including equipment"
        }
    }
}
