import SwiftUI
import TrainingDomain
import TrainingRepositories

@Observable
@MainActor
private final class GymSettingsModel {
    private(set) var catalog: GymCatalog?

    func update(_ action: (CoordinatedModelStore) throws -> GymCatalog) throws {
        catalog = try action(TrainingStorage.openStore())
    }
}

struct GymSettingsView: View {
    @State private var model = GymSettingsModel()
    @State private var addingGym = false
    @State private var loadFailed = false

    var body: some View {
        NavigationStack {
            Group {
                if let catalog = model.catalog {
                    if catalog.gyms.isEmpty {
                        ContentUnavailableView {
                            Label("No gym configured", systemImage: "building.2")
                        } actions: {
                            Button("Add gym") { addingGym = true }
                                .buttonStyle(.borderedProminent)
                        }
                    } else {
                        List {
                            Section("Gyms") {
                                ForEach(
                                    catalog.gyms.sorted {
                                        $0.name.localizedStandardCompare($1.name) == .orderedAscending
                                    }
                                ) {
                                    gym in
                                    NavigationLink(value: gym.id) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(verbatim: gym.name)
                                            if gym.id == catalog.activeGymID {
                                                Label("Active gym", systemImage: "checkmark.circle.fill")
                                                    .font(.subheadline)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .toolbar {
                            ToolbarItem(placement: .primaryAction) {
                                Button("Add gym", systemImage: "plus") { addingGym = true }
                            }
                        }
                    }
                } else if loadFailed {
                    ContentUnavailableView {
                        Label("Could not load gyms", systemImage: "exclamationmark.triangle")
                    } actions: {
                        Button("Try again", action: load)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: UUID.self) { gymID in
                if let gym = model.catalog?.gyms.first(where: { $0.id == gymID }) {
                    GymProfileView(gym: gym, model: model)
                }
            }
            .sheet(isPresented: $addingGym) {
                GymNameEditor(title: "Add gym") { name in
                    try model.update { try $0.createGym(name: name) }
                }
            }
            .task { load() }
        }
    }

    private func load() {
        do {
            try model.update { try $0.gymCatalog() }
            loadFailed = false
        } catch {
            loadFailed = true
        }
    }
}

private struct GymProfileView: View {
    enum Editor: Identifiable {
        case name
        case inventory(GymInventory.Kind)
        case equipment(EquipmentDescription?)

        var id: String {
            switch self {
            case .inventory(let kind): "inventory-\(kind)"
            case .name: "name"
            case .equipment(let existing): existing?.id.uuidString ?? "newEquipment"
            }
        }
    }

    let gym: GymProfile
    let model: GymSettingsModel
    @Environment(\.locale) private var locale
    @State private var editor: Editor?
    @State private var selectionFailed = false

    var body: some View {
        List {
            Section {
                if model.catalog?.activeGymID == gym.id {
                    Label("Active gym", systemImage: "checkmark.circle.fill")
                } else {
                    Button("Set as active gym", action: selectGym)
                }
                Button("Rename gym") { editor = .name }
            }
            Section("Shared weights") {
                ForEach(GymInventory.Kind.allCases, id: \.self) { kind in
                    Button(kind.title) { editor = .inventory(kind) }
                }
            }
            Section("Equipment") {
                ForEach(gym.equipment) { item in
                    Button {
                        editor = .equipment(item)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: item.name)
                                .foregroundStyle(.primary)
                            Text(item.kind.title)
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                            if let station = item.station {
                                Text(verbatim: station)
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
                            }
                        }
                    }
                }
                Button("Add equipment", systemImage: "plus") { editor = .equipment(nil) }
            }
        }
        .navigationTitle(Text(verbatim: gym.name))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editor) { editor in
            switch editor {
            case .name:
                GymNameEditor(title: "Rename gym", name: gym.name) { name in
                    try model.update { try $0.renameGym(gym.id, name: name) }
                }
            case .inventory(let kind):
                InventoryEditor(kind: kind, weights: gym.inventory[kind], locale: locale) { weights in
                    try model.update { try $0.saveInventory(weights, for: kind, in: gym.id) }
                    self.editor = nil
                }
            case .equipment(let existing):
                EquipmentEditor(existing: existing, locale: locale) { item in
                    try model.update { try $0.saveEquipment(item, in: gym.id) }
                }
            }
        }
        .alert("Could not select gym", isPresented: $selectionFailed) {
            Button("OK", role: .cancel) {}
        }
    }

    private func selectGym() {
        do {
            try model.update { try $0.selectGym(gym.id) }
        } catch {
            selectionFailed = true
        }
    }
}

private struct GymNameEditor: View {
    @Environment(\.dismiss) private var dismiss
    let title: LocalizedStringKey
    @State var name = ""
    let onSave: (String) throws -> Void
    @State private var saveFailed = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Gym name", text: $name)
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
            .alert("Could not save gym", isPresented: $saveFailed) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private func save() {
        do {
            try onSave(name)
            dismiss()
        } catch {
            saveFailed = true
        }
    }
}
