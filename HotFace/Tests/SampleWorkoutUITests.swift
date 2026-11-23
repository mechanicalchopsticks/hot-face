import XCTest

@MainActor
final class SampleWorkoutUITests: XCTestCase {
    func testFailureSetsAndCorrectionInEnglish() { verifyWalkthrough(spanish: false) }
    func testFailureSetsAndCorrectionInSpanish() { verifyWalkthrough(spanish: true) }

    private func verifyWalkthrough(spanish: Bool) {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["HOTFACE_UI_TEST_STORE_ID"] = UUID().uuidString
        app.launchArguments = [
            "-AppleLanguages", spanish ? "(es)" : "(en)",
            "-AppleLocale", spanish ? "es_CR" : "en_US",
        ]
        app.launch()

        func localized(_ english: String, _ spanishText: String) -> String { spanish ? spanishText : english }
        func tap(_ english: String, _ spanishText: String) {
            let button = app.buttons[localized(english, spanishText)].firstMatch
            XCTAssertTrue(button.waitForExistence(timeout: 5), app.debugDescription)
            button.tap()
        }

        func assertText(_ text: String) {
            let match = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
            XCTAssertTrue(match.waitForExistence(timeout: 5), app.debugDescription)
        }

        tap("Sample workout", "Entrenamiento de ejemplo")
        tap("Start day", "Iniciar día")
        XCTAssertTrue(app.staticTexts["Jalón polea abierto"].exists)
        assertText(localized("To failure", "Fallo"))
        assertText("35 kg")

        tap("Complete set", "Completar serie")
        XCTAssertTrue(app.staticTexts["sample-rest"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.textFields[localized("Actual repetitions", "Repeticiones realizadas")].exists)
        tap("Correct set", "Corregir serie")
        let count = app.textFields[localized("Actual repetitions", "Repeticiones realizadas")]
        XCTAssertTrue(count.waitForExistence(timeout: 5))
        count.tap()
        count.typeText("12")
        tap("Save", "Guardar")
        XCTAssertEqual(app.staticTexts["sample-record-repetitions-0"].label, localized("12 reps", "12 repeticiones"))

        tap("Next set", "Siguiente serie")
        assertText(localized("To failure", "Fallo"))
        tap("Complete set", "Completar serie")
        tap("Next exercise", "Siguiente ejercicio")
        XCTAssertTrue(app.staticTexts["Remo T"].exists)
        assertText(localized("25 lb added", "25 lb añadidos"))

        tap("More", "Más")
        tap("Finish workout", "Finalizar entrenamiento")
        XCTAssertTrue(app.staticTexts[localized("Workout summary", "Resumen del entrenamiento")].exists)
        assertText(localized("Set 1 completed", "Serie 1 completada"))
        assertText(localized("Set 2 completed", "Serie 2 completada"))
        XCTAssertEqual(app.staticTexts["sample-record-repetitions-0"].label, localized("12 reps", "12 repeticiones"))
        XCTAssertEqual(
            app.staticTexts["sample-record-repetitions-1"].label,
            localized("To failure · Reps unspecified", "Fallo · Repeticiones sin registrar"))

        tap("Done", "Listo")
        tap("Sample workout", "Entrenamiento de ejemplo")
        XCTAssertTrue(app.buttons[localized("Start day", "Iniciar día")].exists)
    }
}
