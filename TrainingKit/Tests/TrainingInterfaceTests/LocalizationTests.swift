import Foundation
import Testing
import TrainingDomain

@testable import TrainingInterface

struct LocalizationTests {
    @Test(arguments: [("en_US", "To failure"), ("es_CR", "Fallo")])
    func formatsSegmentsWithoutANumericTarget(localeID: String, name: String) {
        let locale = Locale(identifier: localeID)
        let exercise = ExercisePrescription(name: "Push-up", segments: [.repetitions(8), .toFailure])
        #expect(TrainingDisplayFormat.prescription(exercise, sets: 3, locale: locale) == "3 × (8+\(name))")
    }

    @Test func comparesPreviousAndNewPrescriptions() {
        let locale = Locale(identifier: "es_ES")
        let previous = ExercisePrescription(name: "Curl", segments: Array(repeating: .repetitions(7), count: 3))
        let current = ExercisePrescription(name: "Curl", segments: [.repetitions(8)])
        #expect(TrainingDisplayFormat.prescription(previous, sets: 4, locale: locale) == "4 × (7+7+7)")
        #expect(TrainingDisplayFormat.prescription(current, sets: 3, locale: locale) == "3 × 8")
    }
    @Test(arguments: [("en_US", "12.500001", "12,5"), ("es_ES", "12,500001", "12.5")])
    func editableWeightsRoundTripAndRejectInvalidInput(localeID: String, formatted: String, wrongSeparator: String) {
        let locale = Locale(identifier: localeID)
        let weight = Decimal(12_500_001) / 1_000_000

        #expect(TrainingDisplayFormat.editableWeight(weight, locale: locale) == formatted)
        #expect(TrainingDisplayFormat.parseWeight(formatted, locale: locale) == weight)
        #expect(TrainingDisplayFormat.parseWeight("0", locale: locale) == 0)
        for invalid in ["", wrongSeparator, "12kg", "1e5", "-2", "8 9"] {
            #expect(TrainingDisplayFormat.parseWeight(invalid, locale: locale) == nil)
        }
    }

    @Test(arguments: [
        (WorkoutPhase.ready, "Ready", "En espera"),
        (.preparation, "Get ready", "Prepárate"),
        (.exercise, "Exercise", "Ejercicio"),
        (.paused, "Paused", "En pausa"),
        (.holdPause, "Hold break", "Pausa entre sostenimientos"),
        (.rest, "Rest", "Descanso"),
    ])
    func phaseTitlesUsePackageLocalizations(phase: WorkoutPhase, english: String, spanish: String) {
        var title = phase.title
        title.locale = Locale(identifier: "en_US")
        #expect(String(localized: title) == english)
        title.locale = Locale(identifier: "es_ES")
        #expect(String(localized: title) == spanish)
    }

    @Test(arguments: [
        ("en_US", "12.5", "11/21/2026"),
        ("es_ES", "12,5", "21/11/2026"),
        ("en_ES", "12,5", "21/11/2026"),
    ])
    func regionalFormatsPreserveLoadUnits(localeID: String, decimal: String, date: String) throws {
        let locale = Locale(identifier: localeID)
        let amount = Decimal(125) / 10
        let kilograms = ExerciseLoad(amount: amount, unit: .kg, representation: .perSide, implementCount: 2)
        let pounds = ExerciseLoad(amount: amount, unit: .lb, representation: .perSide, implementCount: 2)
        let sampleDate = try Date("2026-11-21T12:00:00Z", strategy: .iso8601)
        let utc = try #require(TimeZone(secondsFromGMT: 0))

        #expect(TrainingDisplayFormat.load(kilograms, locale: locale) == "\(decimal) kg")
        #expect(TrainingDisplayFormat.load(pounds, locale: locale) == "\(decimal) lb")
        #expect(TrainingDisplayFormat.date(sampleDate, locale: locale, timeZone: utc) == date)
    }
}
