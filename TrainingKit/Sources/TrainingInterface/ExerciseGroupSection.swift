import SwiftUI
import TrainingDomain

public struct ExerciseGroupSection: Identifiable {
    public var id: String? { name }
    private let name: String?
    public let exercises: [ExercisePrescription]
    private let showsHeading: Bool

    public static func sections(for day: RoutineDay) -> [Self] {
        let groups = Dictionary(grouping: day.exercises, by: groupName)
        var seen = Set<String?>()
        return day.exercises.compactMap { exercise in
            let name = groupName(exercise)
            guard seen.insert(name).inserted, let exercises = groups[name] else { return nil }
            return Self(name: name, exercises: exercises, showsHeading: groups.count > 1)
        }
    }

    private static func groupName(_ exercise: ExercisePrescription) -> String? {
        guard let group = exercise.group, !group.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return group
    }

    public func heading(locale: Locale) -> String? {
        guard showsHeading else { return nil }
        return name
            ?? String(
                localized: LocalizedStringResource("Ungrouped", locale: locale, bundle: .atURL(Bundle.module.bundleURL))
            )
    }

    public func move(_ offsets: IndexSet, to destination: Int, in day: inout RoutineDay) {
        // Only replace this group's slots so interleaved exercises keep their position in the routine.
        let slots = day.exercises.indices.filter { Self.groupName(day.exercises[$0]) == name }
        var ordered = slots.map { day.exercises[$0] }
        ordered.move(fromOffsets: offsets, toOffset: destination)
        for (slot, exercise) in zip(slots, ordered) {
            day.exercises[slot] = exercise
        }
    }

    public func delete(_ offsets: IndexSet, from day: inout RoutineDay) {
        let ids = Set(offsets.map { exercises[$0].id })
        day.exercises.removeAll { ids.contains($0.id) }
    }
}
