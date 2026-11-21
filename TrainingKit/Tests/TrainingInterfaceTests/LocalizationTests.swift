import Foundation
import Testing
import TrainingDomain

@testable import TrainingInterface

struct LocalizationTests {
    @Test(arguments: [
        (WorkoutPhase.ready, "Ready", "En espera"),
        (.preparation, "Get ready", "Prepárate"),
        (.exercise, "Exercise", "Ejercicio"),
        (.paused, "Paused", "En pausa"),
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
