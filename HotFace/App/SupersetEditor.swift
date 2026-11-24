import SwiftUI
import TrainingDomain

struct SupersetEditor: View {
    @Environment(\.dismiss) private var dismiss
    let day: RoutineDay
    let available: [ExercisePrescription]
    let defaultSets: Int
    let roundRest: TimeInterval
    let finalRest: TimeInterval
    let isWorkout: Bool
    var usualDay: RoutineDay?
    let save: (SupersetEdit, Bool) throws -> Void

    @State private var selected: Set<UUID> = []
    @State private var rounds = 1
    @State private var rest = SupersetRest()
    @State private var pending: SupersetEdit?
    @State private var failure: LocalizedStringKey?

    var body: some View {
        Form {
            let candidates = available.filter { $0.supersetID == nil }
            if candidates.count >= 2 {
                Section {
                    ForEach(candidates) { exercise in
                        Toggle(
                            isOn: Binding(
                                get: { selected.contains(exercise.id) },
                                set: { include in
                                    if include {
                                        if selected.isEmpty { rounds = exercise.sets ?? defaultSets }
                                        selected.insert(exercise.id)
                                    } else {
                                        selected.remove(exercise.id)
                                    }
                                })
                        ) {
                            Text(verbatim: exercise.name)
                            Text("Sets: \(exercise.sets ?? defaultSets)")
                        }
                    }
                    if selected.count >= 2 {
                        Stepper("Rounds: \(rounds)", value: $rounds, in: 1...Int.max)
                        NavigationLink("Superset rests") {
                            SupersetRestEditor(
                                settings: $rest, defaultRoundRest: roundRest, defaultFinalRest: finalRest)
                        }
                        Button("Create superset") {
                            submit(.create(id: UUID(), members: selected, rounds: rounds, rest: rest))
                        }
                    }
                } header: {
                    Text("Create superset")
                } footer: {
                    if candidates.contains(where: { selected.contains($0.id) && ($0.sets ?? defaultSets) != rounds }) {
                        Text("Each selected exercise will use the chosen number of rounds.")
                    }
                }
            }
            ForEach(groupIDs, id: \.self) { id in
                Section {
                    Button("Dissolve superset") { submit(.dissolve(id: id)) }
                } header: {
                    Text(verbatim: day.exercises.filter { $0.supersetID == id }.map(\.name).joined(separator: " + "))
                }
            }
        }
        .navigationTitle("Supersets")
        .confirmationDialog(
            "Apply superset change",
            isPresented: Binding(
                get: { pending != nil }, set: { if !$0 { pending = nil } }), presenting: pending
        ) { edit in
            Button("This workout only") { commit(edit, usual: false) }
            if canSaveAsUsual(edit) {
                Button("Save as usual") { commit(edit, usual: true) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert(
            failure ?? "",
            isPresented: Binding(
                get: { failure != nil }, set: { if !$0 { failure = nil } })
        ) { Button("OK") {} }
    }

    private var groupIDs: [UUID] {
        var seen = Set<UUID>()
        return available.compactMap(\.supersetID).filter { seen.insert($0).inserted }
    }

    private func canSaveAsUsual(_ edit: SupersetEdit) -> Bool {
        guard var day = usualDay else { return false }
        return (try? day.apply(edit, defaultSets: defaultSets)) != nil
    }

    private func submit(_ edit: SupersetEdit) {
        if isWorkout { pending = edit } else { commit(edit, usual: true) }
    }

    private func commit(_ edit: SupersetEdit, usual: Bool) {
        do {
            try save(edit, usual)
            if !isWorkout { dismiss() }
        } catch SupersetError.incompatibleSetCounts {
            failure = "Choose enough rounds to include all completed sets."
        } catch {
            failure = "Could not update superset"
        }
    }
}
