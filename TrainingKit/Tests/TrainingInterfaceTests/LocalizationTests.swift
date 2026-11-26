import Foundation
import Testing
import TrainingDomain

@testable import TrainingInterface

struct LocalizationTests {
    @Test(arguments: [(0, "0:00"), (59, "0:59"), (60, "1:00"), (75, "1:15")])
    func formatsDuration(seconds: Int, expected: String) {
        #expect(TrainingDisplayFormat.duration(seconds: seconds, locale: Locale(identifier: "en_US")) == expected)
    }

    @Test(arguments: [
        (
            WeightSuggestion.Reason.higherLoad, "Use the next available load and keep the same repetitions.",
            "Usa la siguiente carga disponible y mantén las repeticiones."
        ),
        (
            WeightSuggestion.Reason.lowerLoad, "The effort balance is low. Use the next lighter load.",
            "El saldo de esfuerzo es bajo. Usa la siguiente carga más ligera."
        ),
        (
            WeightSuggestion.Reason.fewerRepetitions, "At the lightest load, move down one repetition step.",
            "Ya estás en la carga mínima. Baja un escalón de repeticiones."
        ),
        (
            WeightSuggestion.Reason.moreRepetitions, "At the heaviest load, move up one repetition step.",
            "Ya estás en la carga máxima. Sube un escalón de repeticiones."
        ),
        (
            WeightSuggestion.Reason.prepareIncrease, "The next load is over 10% heavier. Increase repetitions first.",
            "La siguiente carga es más de un 10 % mayor. Sube primero las repeticiones."
        ),
        (
            WeightSuggestion.Reason.completeBridge,
            "You completed the repetition step. Increase the load and return to the preceding step.",
            "Completaste el escalón de repeticiones. Sube la carga y vuelve al escalón anterior."
        ),
        (
            WeightSuggestion.Reason.increaseAfterFifteen,
            "At 15 repetitions, move to the next load with 10 repetitions.",
            "Al llegar a 15 repeticiones, pasa a la siguiente carga con 10 repeticiones."
        ),
    ])
    func progressionReasons(reason: WeightSuggestion.Reason, english: String, spanish: String) {
        var message = reason.explanation
        message.locale = Locale(identifier: "en_US")
        #expect(String(localized: message) == english)
        message.locale = Locale(identifier: "es_CR")
        #expect(String(localized: message) == spanish)
    }

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
