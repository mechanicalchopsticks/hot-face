import XCTest

@MainActor
final class CatalogDeletionUITests: XCTestCase {
    func testDeletionInEnglish() { verifyDeletion(spanish: false) }
    func testDeletionInSpanish() { verifyDeletion(spanish: true) }

    private func verifyDeletion(spanish: Bool) {
        continueAfterFailure = false
        func label(_ english: String, _ translation: String) -> String { spanish ? translation : english }
        let app = XCUIApplication()
        app.launchEnvironment["HOTFACE_UI_TEST_STORE_ID"] = UUID().uuidString
        app.launchArguments = [
            "-AppleLanguages", spanish ? "(es)" : "(en)", "-AppleLocale", spanish ? "es_ES" : "en_US",
        ]
        app.launch()

        func button(_ title: String) -> XCUIElement {
            app.buttons.matching(NSPredicate(format: "label == %@ OR label BEGINSWITH %@", title, title + ","))
                .firstMatch
        }
        func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
            for _ in 0..<4 {
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
            if field == label("Routine name", "Nombre de la rutina") || field == label("Day name", "Nombre del día"),
                let existing = input.value as? String
            {
                input.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
            }
            input.typeText(value + "\n")
        }
        func returnFrom(_ title: String, to destination: String) {
            let bar = app.navigationBars[title]
            XCTAssertTrue(bar.waitForExistence(timeout: 5), app.debugDescription)
            bar.buttons["BackButton"].tap()
            XCTAssertTrue(app.navigationBars[destination].waitForExistence(timeout: 5), app.debugDescription)
        }
        let settings = label("Settings", "Ajustes")
        let routines = label("Routines", "Rutinas")
        let cancel = label("Cancel", "Cancelar")
        let save = label("Save", "Guardar")
        let deleteGym = label("Delete gym", "Eliminar gimnasio")
        let deleteItem = label("Delete equipment", "Eliminar equipo")
        let gymMessage = label(
            "Remove North Gym from training? Its routines will be archived and its history will be preserved.",
            "¿Retirar North Gym de los entrenamientos? Sus rutinas se archivarán y se conservará su historial.")
        let itemMessage = label(
            "Remove Cable tower from North Gym? Replace it in assigned exercises. Shared weights and workout history will be preserved.",
            "¿Retirar Cable tower de North Gym? Reemplázalo en los ejercicios asignados. Se conservarán los pesos compartidos y el historial de entrenamiento."
        )

        func openGym() {
            tap(button(settings))
            tap(button("North Gym"))
        }
        func openExercise() {
            tap(button(routines))
            tap(button("Strength"))
            tap(button("Arms"))
            tap(button("Curl"))
        }

        tap(button(settings))
        XCTAssertTrue(app.staticTexts[label("No gym configured", "No hay un gimnasio configurado")].exists)
        for gym in ["North Gym", "South Gym"] {
            tap(button(label("Add gym", "Añadir gimnasio")))
            enter(label("Gym name", "Nombre del gimnasio"), gym)
            tap(button(save))
        }
        tap(button("North Gym"))
        tap(button(label("Add equipment", "Añadir equipo")))
        enter(label("Equipment name", "Nombre del equipo"), "Cable tower")
        tap(button(save))
        tap(button(routines))
        tap(button(label("Add routine", "Añadir rutina")))
        enter(label("Routine name", "Nombre de la rutina"), "Strength")
        tap(button(label("Add day", "Añadir día")))
        enter(label("Day name", "Nombre del día"), "Arms")
        tap(button(label("Add exercise", "Añadir ejercicio")))
        enter(label("Exercise name", "Nombre del ejercicio"), "Curl")
        tap(button(label("Equipment", "Equipos")))
        tap(button("Cable tower"))
        let dayEditor = label("Edit day", "Editar día")
        returnFrom(label("Edit exercise", "Editar ejercicio"), to: dayEditor)
        returnFrom(dayEditor, to: label("Edit routine", "Editar rutina"))
        let activate = button(label("Save and activate", "Guardar y activar"))
        if !activate.exists {
            tap(app.navigationBars.buttons[label("More", "Más")])
        }
        tap(activate)

        app.terminate()
        app.launch()
        openGym()
        tap(button(deleteGym))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label == %@", gymMessage)).firstMatch.exists)
        XCTAssertFalse(button(deleteGym).isEnabled)
        tap(button(label("Replacement gym", "Gimnasio de reemplazo")))
        tap(button("South Gym"))
        tap(button(cancel))
        XCTAssertTrue(app.staticTexts[label("Active gym", "Gimnasio activo")].exists)
        tap(button("Cable tower"))
        tap(button(deleteItem))
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.staticTexts.matching(NSPredicate(format: "label == %@", itemMessage)).firstMatch.exists)
        alert.buttons[cancel].tap()
        tap(button(cancel))
        app.terminate()
        app.launch()

        openExercise()
        let picker = button(label("Equipment", "Equipos"))
        tap(picker)
        XCTAssertTrue(
            button("Cable tower").isSelected || picker.value as? String == "Cable tower"
                || picker.label.contains("Cable tower"))
        tap(button("Cable tower"))
        app.terminate()
        app.launch()

        openGym()
        tap(button("Cable tower"))
        tap(button(deleteItem))
        XCTAssertTrue(alert.staticTexts.matching(NSPredicate(format: "label == %@", itemMessage)).firstMatch.exists)
        alert.buttons[deleteItem].tap()
        XCTAssertFalse(button("Cable tower").exists)
        openExercise()
        let deleted = app.staticTexts[
            label(
                "Assigned equipment was deleted. Choose a replacement.",
                "El equipo asignado se eliminó. Elige un reemplazo.")]
        for _ in 0..<4 where !deleted.exists { app.swipeUp() }
        XCTAssertTrue(deleted.exists)
        app.terminate()
        app.launch()

        openGym()
        tap(button(deleteGym))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label == %@", gymMessage)).firstMatch.exists)
        tap(button(label("Replacement gym", "Gimnasio de reemplazo")))
        tap(button("South Gym"))
        tap(button(deleteGym))
        XCTAssertTrue(app.textFields[label("Routine name", "Nombre de la rutina")].waitForExistence(timeout: 5))
        tap(button(cancel))
        app.terminate()
        app.launch()
        tap(button(settings))
        XCTAssertFalse(button("North Gym").exists)
        tap(button("South Gym"))
        XCTAssertTrue(app.staticTexts[label("Active gym", "Gimnasio activo")].exists)
    }
}
