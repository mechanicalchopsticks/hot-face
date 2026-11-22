import SwiftUI

struct TrainingTabView: View {
    var body: some View {
        TabView {
            Tab("Train", systemImage: "figure.strengthtraining.traditional") {
                EmptySection(
                    "Train",
                    heading: "No active routine",
                    systemImage: "figure.strengthtraining.traditional",
                    message: "Your training days will appear here when a routine is active.")
            }
            Tab("Routines", systemImage: "list.bullet.clipboard") {
                RoutinesView()
            }
            Tab("History", systemImage: "clock") {
                EmptySection(
                    "History",
                    heading: "No workouts yet",
                    systemImage: "clock",
                    message: "Your finished workouts will appear here.")
            }
            Tab("Settings", systemImage: "gearshape") {
                GymSettingsView()
            }
        }
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
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
