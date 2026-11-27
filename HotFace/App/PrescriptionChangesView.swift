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
                values(change.previous, title: "Previous prescription")
                values(change.updated, title: "Updated prescription")
            } header: {
                Text(change.date, format: .dateTime.day().month().year().hour().minute())
            }
        }.navigationTitle("Usual prescription changes")
    }

    private func values(_ exercise: ExercisePrescription, title: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(verbatim: exercise.name).font(.headline)
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
