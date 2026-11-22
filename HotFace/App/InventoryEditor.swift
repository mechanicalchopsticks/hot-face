import SwiftUI
import TrainingDomain
import TrainingInterface
import TrainingRepositories

extension GymInventory.Kind {
    var title: LocalizedStringKey {
        switch self {
        case .plates: "Plate sizes"
        case .dumbbells: "Individual dumbbells"
        case .fixedBars: "Fixed bars (total weight)"
        }
    }
}

struct InventoryEditor: View {
    private struct Row: Identifiable {
        let id = UUID()
        var amount: String
        var unit: ExerciseLoad.Unit
    }

    @Environment(\.dismiss) private var dismiss
    @State private var rows: [Row]
    @State private var errorMessage: LocalizedStringKey?
    let kind: GymInventory.Kind
    let locale: Locale
    let onSave: ([InventoryWeight]) throws -> Void

    init(
        kind: GymInventory.Kind, weights: [InventoryWeight], locale: Locale,
        onSave: @escaping ([InventoryWeight]) throws -> Void
    ) {
        self.kind = kind
        self.locale = locale
        self.onSave = onSave
        _rows = State(
            initialValue: weights.map {
                Row(amount: TrainingDisplayFormat.editableWeight($0.amount, locale: locale), unit: $0.unit)
            })
    }

    var body: some View {
        NavigationStack {
            Form {
                ForEach($rows) { $row in
                    HStack {
                        TextField("Weight", text: $row.amount).keyboardType(.decimalPad)
                        Picker("Weight unit", selection: $row.unit) {
                            Text(verbatim: "kg").tag(ExerciseLoad.Unit.kg)
                            Text(verbatim: "lb").tag(ExerciseLoad.Unit.lb)
                        }.pickerStyle(.segmented).frame(width: 100)
                    }
                }
                .onDelete { rows.remove(atOffsets: $0) }
                Button("Add load", systemImage: "plus") { rows.append(Row(amount: "", unit: rows.last?.unit ?? .kg)) }
            }
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
            .alert(
                "Could not save inventory",
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                if let errorMessage { Text(errorMessage) }
            }
        }
    }

    private func save() {
        do {
            let weights = try rows.map { row in
                guard let amount = TrainingDisplayFormat.parseWeight(row.amount, locale: locale) else {
                    throw GymProfileError.invalidLoads
                }
                return InventoryWeight(amount, row.unit)
            }
            try onSave(weights)
        } catch GymProfileError.invalidLoads {
            errorMessage = "Check the weights and remove duplicate entries. Plate sizes must be positive."
        } catch {
            errorMessage = "Try saving the inventory again."
        }
    }
}
