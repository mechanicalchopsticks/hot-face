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
    @State private var plates: [PlateRow]
    @State private var errorMessage: LocalizedStringKey?

    private struct LoadRow: Identifiable {
        let id = UUID()
        var weight = ""
    }

    private struct PlateRow: Identifiable {
        let id = UUID()
        var weight = ""
        var count = ""
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
        _plates = State(
            initialValue: existing?.plates.map { PlateRow(weight: format($0.weight), count: String($0.count)) } ?? [])
    }

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
                Section("Available loads") {
                    ForEach($loads) { $load in
                        TextField("Weight", text: $load.weight)
                            .keyboardType(.decimalPad)
                    }
                    .onDelete { loads.remove(atOffsets: $0) }
                    Button("Add load", systemImage: "plus") { loads.append(LoadRow()) }
                }
                if kind == .barbell || kind == .plateLoadedMachine || !baseWeight.isEmpty || !plates.isEmpty {
                    Section {
                        TextField("Base weight (optional)", text: $baseWeight)
                            .keyboardType(.decimalPad)
                    }
                    Section("Plate inventory") {
                        ForEach($plates) { $plate in
                            VStack {
                                TextField("Plate weight", text: $plate.weight)
                                    .keyboardType(.decimalPad)
                                TextField("Number of plates", text: $plate.count)
                                    .keyboardType(.numberPad)
                            }
                        }
                        .onDelete { plates.remove(atOffsets: $0) }
                        Button("Add plates", systemImage: "plus") { plates.append(PlateRow()) }
                    }
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
            item.availableLoads = try loads.map { try parseWeight($0.weight) }
            item.baseWeight =
                baseWeight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : try parseWeight(baseWeight)
            item.plates = try plates.map { row in
                guard let count = Int(row.count.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                    throw GymProfileError.invalidLoads
                }
                return PlateInventory(weight: try parseWeight(row.weight), count: count)
            }
            try onSave(item)
            dismiss()
        } catch GymProfileError.invalidLoads {
            errorMessage = "Enter a valid weight for each load and a positive weight and count for each plate entry."
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
