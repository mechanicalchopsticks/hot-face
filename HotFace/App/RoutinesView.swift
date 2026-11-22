import SwiftUI
import TrainingDomain
import TrainingInterface
import TrainingRepositories

struct RoutinesView: View {
    @State private var gym: GymProfile?
    @State private var routines: [ManualRoutine] = []
    @State private var draft: ManualRoutine?
    @State private var loadFailed = false

    var body: some View {
        NavigationStack {
            Group {
                if loadFailed {
                    ContentUnavailableView {
                        Label("Could not load routines", systemImage: "exclamationmark.triangle")
                    } actions: {
                        Button("Try again", action: reload)
                    }
                } else if let gym {
                    List {
                        Section {
                            ForEach(routines) { routine in
                                Button {
                                    draft = routine
                                } label: {
                                    Text(verbatim: routine.plan.name)
                                }
                            }
                            Button("Add routine", systemImage: "plus") { draft = ManualRoutine(gymID: gym.id) }
                        } header: {
                            Text(verbatim: gym.name)
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "No gym configured", systemImage: "building.2",
                        description: Text("Add a gym in Settings to create a routine."))
                }
            }
            .navigationTitle("Routines")
            .onAppear(perform: reload)
            .sheet(item: $draft, onDismiss: reload) { draft in
                if let gym {
                    RoutineEditor(draft: draft, gym: gym)
                }
            }
        }
    }

    private func reload() {
        do {
            let store = try TrainingStorage.openStore()
            let catalog = try store.gymCatalog()
            gym = catalog.gyms.first { $0.id == catalog.activeGymID }
            routines = try gym.map { try store.editableRoutines(in: $0.id) } ?? []
            loadFailed = false
        } catch { loadFailed = true }
    }
}

private enum EditorRoute: Hashable {
    case day(UUID)
    case exercise(day: UUID, exercise: UUID)
}

private struct RoutineEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State var draft: ManualRoutine
    let gym: GymProfile
    @State private var path: [EditorRoute] = []
    @State private var errorMessage: LocalizedStringKey?

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                TextField("Routine name", text: $draft.plan.name)
                Section("Days") {
                    ForEach(draft.plan.days) { day in
                        NavigationLink(value: EditorRoute.day(day.id)) {
                            if day.name.isEmpty { Text("Unnamed day") } else { Text(verbatim: day.name) }
                        }
                    }
                    .onMove { draft.plan.days.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { draft.plan.days.remove(atOffsets: $0) }
                    Button("Add day", systemImage: "plus") {
                        let day = RoutineDay(name: "", exercises: [])
                        draft.plan.days.append(day)
                        path.append(.day(day.id))
                    }
                }
                Section("Routine defaults") {
                    Stepper("Sets: \(draft.plan.defaultSets)", value: $draft.plan.defaultSets, in: 1...Int.max)
                    RestStepper(title: "Between sets", seconds: $draft.plan.restBetweenSets)
                    RestStepper(title: "Between exercises", seconds: $draft.plan.restBetweenExercises)
                }
            }
            .navigationTitle("Edit routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { EditButton() }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
            .navigationDestination(for: EditorRoute.self) { route in
                switch route {
                case .day(let id):
                    if let day = $draft.plan.days.first(where: { $0.wrappedValue.id == id }) {
                        dayEditor(day)
                    }
                case .exercise(let dayID, let exerciseID):
                    if let day = $draft.plan.days.first(where: { $0.wrappedValue.id == dayID }),
                        let exercise = day.exercises.first(where: { $0.wrappedValue.id == exerciseID })
                    {
                        ExerciseEditor(exercise: exercise, gym: gym, defaults: draft.plan)
                    }
                }
            }
            .alert(
                "Could not save routine",
                isPresented: Binding(
                    get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                if let errorMessage { Text(errorMessage) }
            }
        }
    }

    private func dayEditor(_ day: Binding<RoutineDay>) -> some View {
        Form {
            TextField("Day name", text: day.name)
            ForEach(ExerciseGroupSection.sections(for: day.wrappedValue)) { section in
                Section {
                    ForEach(section.exercises) { exercise in
                        NavigationLink(value: EditorRoute.exercise(day: day.wrappedValue.id, exercise: exercise.id)) {
                            if exercise.name.isEmpty { Text("Unnamed exercise") } else { Text(verbatim: exercise.name) }
                        }
                    }
                    .onMove { section.move($0, to: $1, in: &day.wrappedValue) }
                    .onDelete { section.delete($0, from: &day.wrappedValue) }
                } header: {
                    if let heading = section.heading(locale: locale) {
                        Text(verbatim: heading).textCase(nil)
                    } else {
                        Text("Exercises")
                    }
                }
            }
            Section {
                Button("Add exercise", systemImage: "plus") {
                    let exercise = ExercisePrescription(name: "", segments: [.repetitions(8)])
                    day.wrappedValue.exercises.append(exercise)
                    path.append(.exercise(day: day.wrappedValue.id, exercise: exercise.id))
                }
            }
        }
        .navigationTitle("Edit day")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
    }

    private func save() {
        do {
            try TrainingStorage.openStore().saveRoutine(draft)
            dismiss()
        } catch RoutineEditorError.incompletePlan {
            errorMessage =
                "Name the routine, each day and each exercise. Add at least one day, an exercise per day and a segment per exercise."
        } catch RoutineEditorError.changedRoutine {
            errorMessage = "This routine changed. Reopen it to edit the latest version."
        } catch {
            errorMessage = "Try saving the routine again."
        }
    }
}
