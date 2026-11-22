import Foundation
import Testing
import TrainingDomain
import TrainingInterface

struct ExerciseGroupSectionTests {
    private func day(groups: [String?]) -> RoutineDay {
        let exercises = groups.enumerated().map { index, group in
            var exercise = ExercisePrescription(name: "Exercise \(index)", segments: [.repetitions(8)])
            exercise.group = group
            return exercise
        }
        return RoutineDay(name: "Day", exercises: exercises)
    }

    @Test(arguments: ["en", "es"])
    func singleVisibleGroup(language: String) throws {
        for group in [nil, "Pierna"] as [String?] {
            let day = day(groups: [group, group])
            let sections = ExerciseGroupSection.sections(for: day)
            #expect(sections.count == 1)
            let section = try #require(sections.first)
            #expect(section.heading(locale: Locale(identifier: language)) == nil)
            #expect(section.exercises == day.exercises)
        }
    }

    @Test(arguments: [("en", "Ungrouped"), ("es", "Sin grupo")])
    func multipleVisibleGroups(language: String, unassigned: String) {
        let locale = Locale(identifier: language)
        for second in ["Core", nil] as [String?] {
            let day = day(groups: ["Pierna", second, "Pierna", second])
            let sections = ExerciseGroupSection.sections(for: day)
            #expect(sections.map { $0.heading(locale: locale) } == ["Pierna", second ?? unassigned])
            #expect(
                sections.map(\.exercises) == [
                    [day.exercises[0], day.exercises[2]], [day.exercises[1], day.exercises[3]],
                ])
        }
    }

    @Test func editingInterleavedExercises() throws {
        var day = day(groups: ["Pierna", nil, "Pierna", nil])
        let original = day.exercises
        var sections = ExerciseGroupSection.sections(for: day)
        try #require(sections.first).move([1], to: 0, in: &day)
        #expect(day.exercises == [original[2], original[1], original[0], original[3]])
        sections = ExerciseGroupSection.sections(for: day)
        try #require(sections.last).delete([0], from: &day)
        #expect(day.exercises == [original[2], original[0], original[3]])
    }
}
