import CoreTransferable
import SwiftUI
import TrainingDomain
import TrainingInterface
import TrainingRepositories
import UniformTypeIdentifiers

struct HistoryView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var history: WorkoutHistory?
    @State private var changes: [PrescriptionHistoryEntry] = []
    @State private var failed = false
    @State private var exportFiles: [ExportedCSV] = []
    @State private var exporting = false
    @State private var exportFailed = false

    var body: some View {
        NavigationStack {
            List {
                if failed {
                    Button("Could not load history. Try again", action: reload)
                } else if let history {
                    NavigationLink("Notes") { HistoryNotesView(sessionID: nil) }
                    if !changes.isEmpty {
                        NavigationLink("Usual prescription changes") { PrescriptionChangesView(changes: changes) }
                    }
                    if history.sessions.isEmpty {
                        ContentUnavailableView(
                            "No workouts yet", systemImage: "clock",
                            description: Text("Your finished workouts will appear here."))
                    } else {
                        NavigationLink("Progress and records") { ProgressViewList(groups: history.progress) }
                        ForEach(history.sessions) { session in
                            NavigationLink {
                                HistorySessionDetail(session: session)
                            } label: {
                                SessionHeading(session: session)
                            }
                            .accessibilityIdentifier("historySession")
                        }
                    }
                }
            }
            .navigationTitle("History")
            .toolbar {
                Button("Export CSV", systemImage: "square.and.arrow.up") {
                    do {
                        exportFiles = try TrainingStorage.openStore().exportHistoryCSV().map(ExportedCSV.init)
                        exporting = true
                    } catch { exportFailed = true }
                }.accessibilityIdentifier("exportHistoryCSV")
            }
            .fileExporter(isPresented: $exporting, items: exportFiles, contentTypes: [.commaSeparatedText]) { result in
                if case .failure = result { exportFailed = true }
                exportFiles = []
            } onCancellation: {
                exportFiles = []
            }
            .alert("Could not export history", isPresented: $exportFailed) { Button("OK") {} }
            .onAppear(perform: reload)
            .onChange(of: scenePhase) { if scenePhase == .active { reload() } }
        }
    }

    private func reload() {
        do {
            let store = try TrainingStorage.openStore()
            history = try store.workoutHistory()
            changes = try store.prescriptionChanges()
            failed = false
        } catch { failed = true }
    }
}

private struct SessionHeading: View {
    let session: WorkoutSummary
    var showsDurationLabel = false
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.finishedAt, style: .date).font(.caption).foregroundStyle(.secondary)
            Text(verbatim: session.name).font(.headline)
            Text(verbatim: "\(session.snapshot.routineName) · \(session.snapshot.gymName)")
            HStack {
                Text(session.partial ? "Partially completed" : "Completed")
                if session.duration >= 0 {
                    if showsDurationLabel { Text("Total duration") }
                    let units: Set<Duration.UnitsFormatStyle.Unit> =
                        session.duration < 60 ? [.seconds] : [.hours, .minutes]
                    Text(
                        Duration.seconds(session.duration),
                        format: .units(
                            allowed: units, width: .abbreviated))
                } else {
                    Text("Duration unknown")
                }
            }.font(.subheadline).foregroundStyle(.secondary)
        }
    }
}

private struct HistorySessionDetail: View {
    let session: WorkoutSummary
    @Environment(\.locale) private var locale

    var body: some View {
        List {
            SessionHeading(session: session, showsDurationLabel: true)
            NavigationLink("Session notes") { HistoryNotesView(sessionID: session.id) }
            ForEach(session.exercises) { exercise in
                Section {
                    Text(
                        verbatim: TrainingDisplayFormat.prescription(
                            exercise.prescription, sets: exercise.prescription.sets ?? 0, locale: locale))
                    if let equipment = session.snapshot.equipment.first(where: {
                        $0.id == exercise.prescription.equipmentID
                    }) {
                        EquipmentName(equipment: equipment, gymID: session.snapshot.gymID)
                    }
                    if let effort = exercise.effort { Text(effort == .easy ? "Easy" : "Hard") }
                    let byNumber = Dictionary(grouping: exercise.sets, by: \.number)
                    let count = max(exercise.prescription.sets ?? 0, exercise.sets.last?.number ?? 0)
                    ForEach(0..<count, id: \.self) { index in
                        if let sets = byNumber[index + 1] {
                            ForEach(sets) { set in RecordedSetView(set: set) }
                        } else {
                            LabeledContent("Set \(index + 1)") {
                                Text(exercise.skipped ? "Skipped" : "Unperformed")
                            }
                        }
                    }
                } header: {
                    Text(verbatim: exercise.prescription.name)
                }
            }
        }.navigationTitle("Workout details").navigationBarTitleDisplayMode(.inline)
    }
}

private struct EquipmentName: View {
    let equipment: EquipmentDescription
    let gymID: UUID
    var body: some View {
        if equipment.isGeneric(in: gymID) { Text(equipment.kind.title) } else { Text(verbatim: equipment.name) }
    }
}

private struct ProgressViewList: View {
    let groups: [ExerciseProgress]
    @Environment(\.locale) private var locale
    var body: some View {
        List(groups) { group in
            NavigationLink {
                List {
                    Section("Personal records") {
                        if let load = group.heaviestLoad {
                            LabeledContent("Heaviest load", value: TrainingDisplayFormat.load(load, locale: locale))
                        }
                        if let reps = group.mostRepetitions {
                            LabeledContent("Most repetitions", value: reps.formatted())
                        }
                        if let seconds = group.longestHold {
                            LabeledContent(
                                "Longest hold", value: TrainingDisplayFormat.duration(seconds: seconds, locale: locale))
                        }
                        if group.heaviestLoad == nil && group.mostRepetitions == nil && group.longestHold == nil {
                            Text("No measured record")
                        }
                    }
                    Section("Performed sets") {
                        ForEach(group.sets) { set in
                            VStack(alignment: .leading) {
                                Text(set.performedAt, style: .date).font(.caption)
                                RecordedSetView(set: set)
                            }
                        }
                    }
                }.navigationTitle(Text(verbatim: group.id.name))
            } label: {
                VStack(alignment: .leading) {
                    Text(verbatim: group.id.name).font(.headline)
                    Text(verbatim: group.gymName)
                    if let item = group.equipment { EquipmentName(equipment: item, gymID: group.id.gymID) }
                    if let variant = group.id.variant { Text(verbatim: variant) }
                    if let station = group.id.station { Text(verbatim: station) }
                    if let band = group.id.bandColor { BandColorLabel(color: band) }
                    if group.id.perSide { Text("Per side") }
                    if let unit = group.id.unit, let representation = group.id.representation {
                        HStack {
                            Text(verbatim: unit.rawValue)
                            Text(representation.title)
                        }
                        if let count = group.id.implementCount, count > 1 {
                            LabeledContent("Dumbbells used", value: count.formatted())
                        }
                    }
                }
            }
        }.navigationTitle("Progress and records")
    }
}

private struct ExportedCSV: Transferable {
    let file: HistoryCSVFile

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { item in item.file.data }
            .suggestedFileName { $0.file.name }
    }
}
