import SwiftUI
import TrainingDomain
import TrainingInterface
import TrainingRepositories

struct PrescriptionChangesView: View {
    let changes: [PrescriptionHistoryEntry]
    @Environment(\.locale) private var locale

    var body: some View {
        List(changes) { change in
            Section {
                if let previous = change.previous {
                    values(
                        previous, equipment: change.previousEquipment,
                        title: change.updated == nil ? "Removed exercise" : "Previous prescription")
                }
                if let updated = change.updated {
                    values(
                        updated, equipment: change.updatedEquipment,
                        title: change.previous == nil ? "Added exercise" : "Updated prescription")
                }
            } header: {
                Text(change.date, format: .dateTime.day().month().year().hour().minute())
                if change.origin.hasPrefix("suggestion.") { Text("Accepted suggestion") }
            }
        }.navigationTitle("Usual prescription changes")
    }

    private func values(
        _ exercise: ExercisePrescription, equipment: PrescriptionHistoryEntry.Equipment?, title: LocalizedStringKey
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(verbatim: exercise.name).font(.headline)
            LabeledContent("Equipment") {
                switch equipment {
                case .generic(let kind): Text(kind.title)
                case .named(let name): Text(verbatim: name)
                case .unavailable(let id): Text("Removed equipment · \(id.uuidString)")
                case nil: Text("None")
                }
            }
            if let variant = exercise.variant { Text(verbatim: variant) }
            if let station = exercise.station { Text(verbatim: station) }
            if let color = exercise.bandColor { BandColorLabel(color: color) }
            if let sets = exercise.sets {
                Text(verbatim: TrainingDisplayFormat.prescription(exercise, sets: sets, locale: locale))
            } else {
                Text("Routine default set count")
                Text(verbatim: TrainingDisplayFormat.segments(exercise.segments, locale: locale))
            }
            if exercise.perSide { Text("Per side") }
            if let load = exercise.load.value {
                Text(verbatim: TrainingDisplayFormat.load(load, locale: locale))
                Text(load.representation.title).font(.caption)
                if load.implementCount > 1 { LabeledContent("Dumbbells used", value: load.implementCount.formatted()) }
                if case .estimated = exercise.load { Text("Estimated load") }
            } else {
                Text("Undefined load")
            }
        }
    }
}
