import SwiftUI
import TrainingDomain
import TrainingInterface
import TrainingRepositories

struct EquipmentEditor: View {
    @Environment(\.dismiss) private var dismiss
    let existing: EquipmentDescription?
    let locale: Locale
    let onSave: (EquipmentDescription) throws -> Void
    @State private var name: String
    @State private var station: String
    @State private var kind: EquipmentDescription.Kind
    @State private var unit: ExerciseLoad.Unit
    @State private var loads: [LoadRow]
    @State private var baseWeight: String
    @State private var maximumPerSide: String
    @State private var errorMessage: LocalizedStringKey?

    private struct LoadRow: Identifiable {
        let id = UUID()
        var weight = ""
    }

    init(existing: EquipmentDescription?, locale: Locale, onSave: @escaping (EquipmentDescription) throws -> Void) {
        self.existing = existing
        self.locale = locale
        self.onSave = onSave
        _name = State(initialValue: existing?.name ?? "")
        _station = State(initialValue: existing?.station ?? "")
        _kind = State(initialValue: existing?.kind ?? .dumbbell)
        _unit = State(initialValue: existing?.unit ?? .kg)
        func format(_ weight: Decimal) -> String {
            TrainingDisplayFormat.editableWeight(weight, locale: locale)
        }
        _loads = State(initialValue: existing?.availableLoads.map { LoadRow(weight: format($0)) } ?? [])
        _baseWeight = State(initialValue: existing?.baseWeight.map(format) ?? "")
        _maximumPerSide = State(initialValue: existing?.maximumAddedWeightPerSide.map(format) ?? "")
    }

    private var usesPlates: Bool { kind == .barbell || kind == .plateLoadedMachine }

    private var editsEquipmentLoads: Bool { !usesPlates && kind != .dumbbell && kind != .fixedBar }

    private var title: LocalizedStringKey { existing == nil ? "Add equipment" : "Edit equipment" }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Equipment name", text: $name)
                    TextField("Station (optional)", text: $station)
                    Picker("Equipment type", selection: $kind) {
                        ForEach(EquipmentDescription.Kind.allCases, id: \.self) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    Picker("Weight unit", selection: $unit) {
                        Text(verbatim: "kg").tag(ExerciseLoad.Unit.kg)
                        Text(verbatim: "lb").tag(ExerciseLoad.Unit.lb)
                    }
                }
                if editsEquipmentLoads {
                    Section("Available loads") {
                        ForEach($loads) { $load in
                            TextField("Weight", text: $load.weight).keyboardType(.decimalPad)
                        }
                        .onDelete { loads.remove(atOffsets: $0) }
                        Button("Add load", systemImage: "plus") { loads.append(LoadRow()) }
                    }
                }
                if usesPlates || !baseWeight.isEmpty {
                    Section {
                        TextField("Base weight (optional)", text: $baseWeight).keyboardType(.decimalPad)
                        if usesPlates {
                            TextField("Maximum added per side (optional)", text: $maximumPerSide).keyboardType(
                                .decimalPad)
                        }
                    }
                }
            }
            .onChange(of: kind) { previous, selected in
                if existing == nil && selected == .barbell && baseWeight.isEmpty {
                    unit = .lb
                    baseWeight = "45"
                } else if existing == nil && previous == .barbell && baseWeight == "45" && unit == .lb {
                    baseWeight = ""
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert(
                "Could not save equipment",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                if let errorMessage { Text(errorMessage) }
            }
        }
    }

    private func parseWeight(_ text: String) throws -> Decimal {
        guard let weight = TrainingDisplayFormat.parseWeight(text, locale: locale) else {
            throw GymProfileError.invalidLoads
        }
        return weight
    }

    private func save() {
        do {
            var item = EquipmentDescription(id: existing?.id ?? UUID(), name: name, kind: kind, unit: unit)
            item.station = station.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : station
            if editsEquipmentLoads {
                item.availableLoads = try loads.map { try parseWeight($0.weight) }
            } else if usesPlates && existing?.kind == kind {
                item.availableLoads = existing?.availableLoads ?? []
            }
            item.baseWeight =
                baseWeight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : try parseWeight(baseWeight)
            if usesPlates && !maximumPerSide.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                item.maximumAddedWeightPerSide = try parseWeight(maximumPerSide)
            }
            try onSave(item)
            dismiss()
        } catch GymProfileError.invalidLoads {
            errorMessage = "Enter a valid weight."
        } catch {
            errorMessage = "Try saving the equipment again."
        }
    }
}

extension EquipmentDescription.Kind {
    var title: LocalizedStringKey {
        switch self {
        case .dumbbell: "Dumbbells"
        case .barbell: "Barbell with plates"
        case .fixedBar: "Fixed-weight bars"
        case .selectorizedMachine: "Selectorized machine"
        case .plateLoadedMachine: "Plate-loaded machine"
        case .bodyweight: "Bodyweight"
        case .band: "Resistance bands"
        case .cardio: "Cardio"
        }
    }
}
