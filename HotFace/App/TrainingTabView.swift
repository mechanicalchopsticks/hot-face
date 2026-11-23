import SwiftUI
import TrainingRepositories

struct TrainingTabView: View {
    private enum Destination { case train, routines, history, settings }
    @State private var selectedTab = Destination.train
    @State private var newRoutineGymID: UUID?

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Train", systemImage: "figure.strengthtraining.traditional", value: .train) {
                ActiveRoutineView()
            }
            Tab("Routines", systemImage: "list.bullet.clipboard", value: .routines) {
                RoutinesView(newRoutineGymID: $newRoutineGymID)
            }
            Tab("History", systemImage: "clock", value: .history) {
                EmptySection(
                    "History",
                    heading: "No workouts yet",
                    systemImage: "clock",
                    message: "Your finished workouts will appear here.")
            }
            Tab("Settings", systemImage: "gearshape", value: .settings) {
                GymSettingsView { gymID in
                    newRoutineGymID = gymID
                    selectedTab = .routines
                }
            }
        }
    }
}

private struct ActiveRoutineView: View {
    @State private var active: ManualRoutine?
    @State private var loadFailed = false
    @State private var showSampleWorkout = false

    var body: some View {
        NavigationStack {
            Group {
                if loadFailed {
                    ContentUnavailableView {
                        Label("Could not load routines", systemImage: "exclamationmark.triangle")
                    } actions: {
                        Button("Try again", action: reload)
                    }
                } else if let active {
                    List {
                        Section {
                            ForEach(active.plan.days) { day in Text(verbatim: day.name) }
                        } header: {
                            Text(verbatim: active.plan.name)
                        }
                    }
                } else {
                    EmptySectionContent(
                        heading: "No active routine", systemImage: "figure.strengthtraining.traditional",
                        message: "Your training days will appear here when a routine is active.")
                }
            }
            .navigationTitle("Train")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Sample workout") { showSampleWorkout = true }
            }
            .sheet(isPresented: $showSampleWorkout, onDismiss: SampleWorkoutController.shared.close) {
                SampleWorkoutView()
            }
        }
        .onAppear(perform: reload)
    }

    private func reload() {
        do {
            active = try TrainingStorage.openStore().activeRoutine()
            loadFailed = false
        } catch { loadFailed = true }
    }
}

private struct EmptySection: View {
    let title: LocalizedStringKey
    let heading: LocalizedStringKey
    let systemImage: String
    let message: LocalizedStringKey

    init(_ title: LocalizedStringKey, heading: LocalizedStringKey, systemImage: String, message: LocalizedStringKey) {
        self.title = title
        self.heading = heading
        self.systemImage = systemImage
        self.message = message
    }

    var body: some View {
        NavigationStack {
            EmptySectionContent(heading: heading, systemImage: systemImage, message: message)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct EmptySectionContent: View {
    let heading: LocalizedStringKey
    let systemImage: String
    let message: LocalizedStringKey

    var body: some View {
        GeometryReader { viewport in
            ScrollView {
                ContentUnavailableView {
                    Label(heading, systemImage: systemImage)
                } description: {
                    Text(message)
                }
                .frame(maxWidth: .infinity, minHeight: viewport.size.height)
            }
            .defaultScrollAnchor(.top, for: .initialOffset)
        }
    }
}
