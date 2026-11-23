import XCTest

@MainActor
final class BandColorUITests: XCTestCase {
    func testBandColorsPersistAndDisplayInBothLanguages() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["HOTFACE_UI_TEST_STORE_ID"] = UUID().uuidString
        func launch(language: String, locale: String) {
            app.launchArguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", locale]
            app.launch()
        }

        func button(_ title: String) -> XCUIElement {
            app.buttons.matching(NSPredicate(format: "label == %@ OR label BEGINSWITH %@", title, title + ","))
                .firstMatch
        }
        func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
            for _ in 0..<5 {
                if element.exists && element.isHittable {
                    element.tap()
                    return
                }
                app.swipeUp()
            }
            XCTAssertTrue(element.waitForExistence(timeout: 4), app.debugDescription, file: file, line: line)
            element.tap()
        }
        func enter(_ field: String, _ value: String) {
            let input = app.textFields[field]
            tap(input)
            input.typeText(value + "\n")
        }
        func back(from title: String) {
            tap(app.navigationBars[title].buttons["BackButton"])
        }
        let names = ["Band curl", "Band row"]
        launch(language: "en", locale: "en_US")
        tap(button("Settings"))
        tap(button("Add gym"))
        enter("Gym name", "Band Gym")
        tap(button("Save"))
        tap(button("Routines"))
        tap(button("Add routine"))
        enter("Routine name", "Band Routine")
        tap(button("Add day"))
        enter("Day name", "Band Day")
        for (name, color) in zip(names, ["Pink", "Light blue"]) {
            tap(button("Add exercise"))
            enter("Exercise name", name)
            tap(button("Equipment"))
            tap(button("Resistance bands"))
            tap(button("Band color"))
            tap(button(color))
            back(from: "Edit exercise")
        }
        back(from: "Edit day")
        let activate = button("Save and activate")
        if !activate.exists { tap(app.navigationBars.buttons["More"]) }
        tap(activate)
        app.terminate()

        for (language, locale) in [("en", "en_US"), ("es", "es_CR")] {
            let spanish = language == "es"
            launch(language: language, locale: locale)
            tap(button(spanish ? "Rutinas" : "Routines"))
            tap(button("Band Routine"))
            tap(button("Band Day"))
            let colors = spanish ? ["Rosado", "Celeste"] : ["Pink", "Light blue"]
            let editor = spanish ? "Editar ejercicio" : "Edit exercise"
            for (name, color) in zip(names, colors) {
                tap(button(name))
                let colorRow = button(spanish ? "Color de banda" : "Band color")
                for _ in 0..<4 where !colorRow.exists { app.swipeUp() }
                XCTAssertTrue(
                    colorRow.label.contains(color) || colorRow.value as? String == color,
                    app.debugDescription)
                back(from: editor)
            }
            app.terminate()
        }
    }
}
