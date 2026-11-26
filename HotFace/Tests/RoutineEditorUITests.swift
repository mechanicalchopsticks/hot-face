import XCTest

@MainActor
final class RoutineEditorUITests: XCTestCase {
    func testSuggestedNamesInEnglish() { verifySuggestedNames(spanish: false) }
    func testSuggestedNamesInSpanish() { verifySuggestedNames(spanish: true) }
    func testCustomSetCountInEnglish() { verifyCustomSetCount(spanish: false) }
    func testCustomSetCountInSpanish() { verifyCustomSetCount(spanish: true) }

    func testGymNameKeepsDraftSpacesUntilSave() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["HOTFACE_UI_TEST_STORE_ID"] = UUID().uuidString
        launch(app, spanish: false)
        tap(button("Settings", in: app))
        tap(button("Add gym", in: app))
        let field = app.textFields["Gym name"]
        tap(field)
        field.typeText(" ")
        XCTAssertFalse(button("Save", in: app).isEnabled)
        field.typeText("North ")
        XCTAssertEqual(field.value as? String, " North ")
        field.typeText("Gym ")
        tap(button("Save", in: app))
        XCTAssertTrue(button("North Gym", in: app).waitForExistence(timeout: 5))
    }

    func testWeightProgressionPreferenceSurvivesCancellingExerciseEdits() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["HOTFACE_UI_TEST_STORE_ID"] = UUID().uuidString
        func press(_ title: String) { tap(button(title, in: app)) }
        let picker = app.buttons["weightProgressionMode"]
        launch(app, spanish: false)
        press("Settings")
        XCTAssertTrue(app.staticTexts["No gym configured"].waitForExistence(timeout: 5))
        tap(picker)
        press("Aggressive")
        press("Add gym")
        enter("Gym", in: app.textFields["Gym name"])
        press("Save")
        press("Routines")
        press("Add routine")
        press("Add day")
        press("Add exercise")
        for _ in 0..<6 where !picker.isHittable { app.swipeUp() }
        XCTAssertTrue(
            picker.label.contains("Aggressive") || picker.value as? String == "Aggressive", picker.debugDescription)
        tap(picker)
        press("Conservative")
        tap(app.navigationBars["Edit exercise"].buttons["BackButton"])
        tap(app.navigationBars["Edit day"].buttons["BackButton"])
        press("Cancel")
        press("Settings")
        XCTAssertTrue(
            picker.label.contains("Conservative") || picker.value as? String == "Conservative", picker.debugDescription)
    }

    func testWeightProgressionOffersAfterRelaunch() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["HOTFACE_UI_TEST_STORE_ID"] = UUID().uuidString
        func press(_ title: String) { tap(button(title, in: app)) }
        func reveal(_ element: XCUIElement) {
            for _ in 0..<5 where !element.isHittable { app.swipeUp() }
            XCTAssertTrue(element.isHittable, app.debugDescription)
        }
        launch(app, spanish: false)
        press("Settings")
        let mode = app.buttons["weightProgressionMode"]
        tap(mode)
        press("Conservative")
        press("Add gym")
        enter("Gym", in: app.textFields["Gym name"])
        press("Save")
        press("Gym")
        press("Add equipment")
        enter("Stack", in: app.textFields["Equipment name"])
        press("Equipment type")
        press("Selectorized machine")
        press("Weight unit")
        press("lb")
        for (index, amount) in ["50", "57.5"].enumerated() {
            press("Add load")
            let field = app.textFields.matching(identifier: "Weight").element(boundBy: index)
            tap(field)
            field.typeText(amount)
        }
        press("Save")
        tap(app.navigationBars["Gym"].buttons["BackButton"])
        press("Routines")
        press("Add routine")
        for count in [4, 3, 2] { tap(app.steppers["Sets: \(count)"].buttons.element(boundBy: 0)) }
        press("Add day")
        for name in ["Row", "Press"] {
            press("Add exercise")
            enter(name, in: app.textFields["Exercise name"])
            reveal(app.steppers["Reps: 10"])
            reveal(button("Equipment", in: app))
            press("Equipment")
            press("Stack")
            reveal(button("Usual load", in: app))
            press("Usual load")
            press("50 lb")
            tap(app.navigationBars["Usual load"].buttons["BackButton"])
            tap(app.navigationBars["Edit exercise"].buttons["BackButton"])
        }
        activateDayAndOpenTrain(in: app)
        for session in 1...2 {
            press("Day 1")
            if session == 1 { allowWorkoutAccessIfRequested(app) }
            press("Complete set")
            if button("End rest", in: app).exists { press("End rest") }
            press("Complete set")
            for _ in 0..<2 {
                let menu = button("Rate exercise", in: app)
                reveal(menu)
                menu.coordinate(withNormalizedOffset: CGVector(dx: 0.16, dy: 0.5)).tap()
                tap(app.buttons["Easy"].firstMatch)
            }
            press("Done")
        }
        press("Day 1")
        func checkOffer(load: String, reps: Int) {
            let field = button("Load", in: app)
            reveal(field)
            XCTAssertTrue(field.label.contains(load) || field.value as? String == load, field.debugDescription)
            XCTAssertTrue(app.steppers["\(reps) reps"].exists)
        }
        checkOffer(load: "50 lb", reps: 12)
        press("Complete set")
        if button("End rest", in: app).exists { press("End rest") }
        press("Close")
        press("Settings")
        tap(mode)
        press("Aggressive")
        app.terminate()
        launch(app, spanish: false)
        press("Settings")
        XCTAssertTrue(mode.label.contains("Aggressive") || mode.value as? String == "Aggressive", mode.debugDescription)
        press("Train")
        press("Continue workout")
        XCTAssertTrue(app.staticTexts["Press"].waitForExistence(timeout: 5))
        checkOffer(load: "57.5 lb", reps: 10)
    }

    func testCancelAndConfirmDiscardFromTrainAndActiveWorkout() {
        continueAfterFailure = false
        let app = XCUIApplication()
        func press(_ title: String) { tap(button(title, in: app)) }
        createDayWithExercises(in: app)
        activateDayAndOpenTrain(in: app)
        for fromTrain in [false, true] {
            press("Day 1")
            if !fromTrain { allowWorkoutAccessIfRequested(app) }
            XCTAssertTrue(app.staticTexts["Set 1 of 4"].waitForExistence(timeout: 5))
            press("Complete set")
            if fromTrain { press("Close") } else { press("More") }
            press("Discard workout")
            XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 6), app.debugDescription)
            tap(app.alerts.buttons["Cancel"])
            if fromTrain {
                XCTAssertTrue(button("Continue workout", in: app).exists)
            } else {
                XCTAssertTrue(app.staticTexts["Set 1 completed"].exists)
                press("More")
            }
            press("Discard workout")
            tap(app.alerts.buttons["Discard workout"])
            XCTAssertTrue(button("Day 1", in: app).waitForExistence(timeout: 8))
            XCTAssertFalse(button("Continue workout", in: app).exists)
        }
    }

    func testOpenWorkoutListActionsAndCompletedFilter() {
        continueAfterFailure = false
        let app = XCUIApplication()
        func press(_ title: String) { tap(button(title, in: app)) }
        createDayWithExercises(in: app, rowGroup: "Upper")
        press("Add exercise")
        enter("Curl", in: app.textFields["Exercise name"])
        press("Exercise group")
        press("Upper")
        tap(app.navigationBars["Edit exercise"].buttons["BackButton"])
        tap(app.navigationBars["Edit day"].buttons["BackButton"])
        for count in [4, 3, 2] { tap(app.steppers["Sets: \(count)"].buttons.element(boundBy: 0)) }
        let activate = button("Save and activate", in: app)
        if !activate.exists { tap(app.navigationBars.buttons["More"]) }
        tap(activate)
        press("Train")
        press("Day 1")
        allowWorkoutAccessIfRequested(app)
        press("Complete set")
        press("Close")
        let row = app.staticTexts["Row"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        let continueButton = button("Continue workout", in: app)
        for name in ["Row", "Curl", "Press"] {
            XCTAssertLessThan(app.staticTexts[name].frame.maxY, continueButton.frame.minY)
        }
        let filter = app.switches["Hide completed"]
        func toggleFilter() { filter.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap() }
        toggleFilter()
        XCTAssertFalse(row.exists)
        toggleFilter()
        XCTAssertTrue(row.exists)
        press("Edit")
        let curl = app.cells.containing(.staticText, identifier: "Curl").firstMatch
        XCTAssertEqual(app.staticTexts.matching(identifier: "Upper").count, 1)
        let firstRow = app.cells.containing(.staticText, identifier: "Row").firstMatch
        let editingList = XCTAttachment(screenshot: app.screenshot())
        editingList.name = "Grouped list in edit mode"
        add(editingList)
        let handle = curl.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.5))
        handle.press(
            forDuration: 0.6, thenDragTo: firstRow.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.15)))
        press("Done")
        XCTAssertLessThan(app.staticTexts["Curl"].frame.midY, app.staticTexts["Row"].frame.midY)
        app.staticTexts["Curl"].swipeLeft()
        press("Postpone exercise")
        press("Continue workout")
        XCTAssertTrue(app.staticTexts["Press"].waitForExistence(timeout: 5))
        press("Close")
        app.staticTexts["Press"].swipeLeft()
        press("Skip exercise")
        press("Continue workout")
        XCTAssertTrue(app.staticTexts["Curl"].waitForExistence(timeout: 5))
    }

    func testInlineFeedbackKeepsCompletedExerciseWhenPreviewChanges() {
        continueAfterFailure = false
        let app = XCUIApplication()
        func press(_ title: String) { tap(button(title, in: app)) }
        createDayWithExercises(in: app, names: ["Row", "Press", "Curl"])
        tap(app.navigationBars["Edit day"].buttons["BackButton"])
        for count in [4, 3, 2] { tap(app.steppers["Sets: \(count)"].buttons.element(boundBy: 0)) }
        let activate = button("Save and activate", in: app)
        if !activate.exists { tap(app.navigationBars.buttons["More"]) }
        tap(activate)
        press("Train")
        press("Day 1")
        allowWorkoutAccessIfRequested(app)
        press("Complete set")
        let question = app.staticTexts["How did Row feel?"]
        XCTAssertTrue(question.waitForExistence(timeout: 5))
        for choice in ["Hard", "OK", "Easy"] { XCTAssertTrue(button(choice, in: app).exists) }
        press("More")
        press("Exercises")
        let curl = app.staticTexts.matching(identifier: "Curl").allElementsBoundByIndex.last(where: \.isHittable)
        guard let curl else { return XCTFail("Missing Curl in the exercise list") }
        curl.swipeLeft()
        press("Select exercise")
        XCTAssertTrue(app.navigationBars["Exercises"].waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["workoutSetName"].label, "Curl")
        XCTAssertTrue(question.exists)
        press("Hard")
        XCTAssertTrue(question.waitForNonExistence(timeout: 5))
        XCTAssertTrue(button("End rest", in: app).exists)
        let countdown = app.staticTexts["Rest remaining"]
        guard let previous = countdown.value as? String else { return XCTFail("Missing countdown") }
        let tick = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value != %@", previous), object: countdown)
        XCTAssertEqual(XCTWaiter.wait(for: [tick], timeout: 5), .completed)
    }

    func testPostponeCyclesInPlaceAndStartsTheDisplayedExercise() {
        continueAfterFailure = false
        let app = XCUIApplication()
        func press(_ title: String) { tap(button(title, in: app)) }
        createDayWithExercises(in: app, names: ["Remo", "Sentadilla", "Press"], sets: 1, spanish: true)
        openWorkoutInSpanish(app)
        let next = app.staticTexts["workoutSetName"]
        let question = app.staticTexts["¿Cómo sentiste Remo?"]
        press("Completar serie")
        XCTAssertTrue(question.waitForExistence(timeout: 5))
        XCTAssertEqual(next.label, "Sentadilla")
        for candidate in ["Press", "Sentadilla", "Press"] {
            press("Posponer")
            XCTAssertEqual(next.label, candidate)
            XCTAssertTrue(question.exists)
        }
        for choice in ["Difícil", "OK", "Fácil"] { XCTAssertTrue(button(choice, in: app).exists) }
        press("OK")
        XCTAssertTrue(question.waitForNonExistence(timeout: 5))
        press("Terminar descanso")
        XCTAssertEqual(next.label, "Press")
        press("Completar serie")
        XCTAssertTrue(app.staticTexts["¿Cómo sentiste Press?"].waitForExistence(timeout: 5))
        XCTAssertEqual(next.label, "Sentadilla")
        XCTAssertFalse(button("Posponer", in: app).exists)
        press("Fácil")
        press("Terminar descanso")
        press("Completar serie")
    }

    func testUpcomingSetExerciseAndSupersetHeadingsInSpanish() {
        continueAfterFailure = false
        let app = XCUIApplication()
        func press(_ title: String) { tap(button(title, in: app)) }
        createDayWithExercises(in: app, names: ["Sentadilla", "Remo", "Press"], sets: 2, spanish: true)
        press("Superseries")
        selectSupersetMembers(in: app, names: ["Remo", "Press"])
        press("Crear superserie")
        openWorkoutInSpanish(app)

        let name = app.staticTexts["workoutSetName"]
        press("Completar serie")
        XCTAssertTrue(app.staticTexts["Siguiente serie"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Serie 2 de 2"].exists)
        XCTAssertEqual(name.label, "Sentadilla")
        press("Terminar descanso")
        press("Completar serie")
        XCTAssertTrue(app.staticTexts["Siguiente ejercicio"].firstMatch.exists)
        XCTAssertEqual(name.label, "Remo")
        press("Terminar descanso")
        press("Completar serie")
        XCTAssertTrue(app.staticTexts["Siguiente ejercicio de la superserie"].exists)
        XCTAssertFalse(button("Terminar descanso", in: app).exists)
        XCTAssertEqual(name.label, "Press")
        XCTAssertTrue(app.staticTexts["Superserie · Ronda 1 de 2"].exists)
        press("Completar serie")
        press("Terminar descanso")
        press("Completar serie")
        XCTAssertTrue(app.staticTexts["Siguiente ejercicio de la superserie"].exists)
        XCTAssertTrue(app.staticTexts["Superserie · Ronda 2 de 2"].exists)
        XCTAssertEqual(name.label, "Press")
        press("Completar serie")
    }

    private func openWorkoutInSpanish(_ app: XCUIApplication) {
        activateDayAndOpenTrain(in: app, spanish: true)
        tap(button("Día 1", in: app))
        allowWorkoutAccessIfRequested(app)
        let complete = button("Completar serie", in: app)
        XCTAssertTrue(complete.wait(for: \.isHittable, toEqual: true, timeout: 15), app.debugDescription)
    }

    func testCreateUsualSupersetAndDissolveForThisWorkout() {
        continueAfterFailure = false
        let app = XCUIApplication()
        func press(_ title: String) { tap(button(title, in: app)) }

        createDayWithExercises(in: app)
        press("Supersets")
        selectSupersetMembers(in: app)
        press("Create superset")
        activateDayAndOpenTrain(in: app)
        press("Day 1")
        allowWorkoutAccessIfRequested(app)
        XCTAssertTrue(app.staticTexts["Superset · Round 1 of 4"].waitForExistence(timeout: 5))
        press("Complete set")
        XCTAssertTrue(app.staticTexts["Press"].exists)
        XCTAssertFalse(button("End rest", in: app).exists)
        press("More")
        press("Exercises")
        press("Supersets")
        press("Dissolve superset")
        press("This workout only")
        XCTAssertTrue(app.staticTexts["Row"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Set 2 of 4"].exists)
        XCTAssertFalse(app.staticTexts["Superset · Round 2 of 4"].exists)
    }

    func testSavingMoreSupersetRoundsRemovesTheReadyExercisesSuggestion() {
        continueAfterFailure = false
        let app = XCUIApplication()
        func press(_ title: String) { tap(button(title, in: app)) }
        createDayWithExercises(in: app)
        activateDayAndOpenTrain(in: app)
        for session in 1...2 {
            press("Day 1")
            if session == 1 { allowWorkoutAccessIfRequested(app) }
            press("Complete set")
            press("Close")
            press("Finish workout")
            press("Finish workout")
            let ratingMenu = button("Rate exercise", in: app)
            XCTAssertTrue(ratingMenu.waitForExistence(timeout: 5))
            ratingMenu.coordinate(withNormalizedOffset: CGVector(dx: 0.16, dy: 0.5)).tap()
            let easy = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Easy'")).firstMatch
            XCTAssertTrue(easy.waitForExistence(timeout: 5), app.debugDescription)
            tap(easy)
            press("Done")
        }
        press("Day 1")
        let suggestion = button("Continue with current values", in: app)
        app.swipeUp()
        XCTAssertTrue(suggestion.waitForExistence(timeout: 5), app.debugDescription)
        tap(suggestion)
        press("More")
        press("Exercises")
        let exerciseList = app.navigationBars["Exercises"]
        tap(exerciseList.buttons["Close"])
        XCTAssertTrue(exerciseList.waitForNonExistence(timeout: 5))
        app.swipeUp()
        XCTAssertFalse(suggestion.exists)
        tap(app.navigationBars["Day 1"].buttons["Close"])
        press("Finish workout")
        press("Finish workout")
        press("Done")
        press("Day 1")
        app.swipeUp()
        XCTAssertTrue(suggestion.waitForExistence(timeout: 5), app.debugDescription)
        press("More")
        press("Exercises")
        press("Supersets")
        selectSupersetMembers(in: app)
        tap(app.steppers["Rounds: 4"].buttons.element(boundBy: 1))
        press("Create superset")
        press("Save as usual")
        XCTAssertTrue(app.staticTexts["Superset · Round 1 of 5"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Row"].exists)
        app.swipeUp()
        XCTAssertTrue(suggestion.waitForNonExistence(timeout: 5), app.debugDescription)
    }

    private func createDayWithExercises(
        in app: XCUIApplication, rowGroup: String? = nil, names: [String] = ["Row", "Press"], sets: Int = 4,
        spanish: Bool = false
    ) {
        app.launchEnvironment["HOTFACE_UI_TEST_STORE_ID"] = UUID().uuidString
        func press(_ title: String) { tap(button(title, in: app)) }
        launch(app, spanish: spanish)
        press(spanish ? "Ajustes" : "Settings")
        XCTAssertTrue(
            app.staticTexts[spanish ? "No hay un gimnasio configurado" : "No gym configured"].waitForExistence(
                timeout: 5), app.debugDescription)
        press(spanish ? "Añadir gimnasio" : "Add gym")
        enter("Gym", in: app.textFields[spanish ? "Nombre del gimnasio" : "Gym name"])
        press(spanish ? "Guardar" : "Save")
        press(spanish ? "Rutinas" : "Routines")
        press(spanish ? "Añadir rutina" : "Add routine")
        for count in stride(from: 4, to: sets, by: -1) {
            tap(app.steppers[spanish ? "Series: \(count)" : "Sets: \(count)"].buttons.element(boundBy: 0))
        }
        press(spanish ? "Añadir día" : "Add day")
        for name in names {
            press(spanish ? "Añadir ejercicio" : "Add exercise")
            let field = app.textFields[spanish ? "Nombre del ejercicio" : "Exercise name"]
            tap(field)
            if !app.keyboards.firstMatch.waitForExistence(timeout: 2) { tap(field) }
            field.typeText(name + "\n")
            if name == "Row", let rowGroup {
                press("Create group…")
                let field = app.alerts.textFields["Group name"]
                tap(field)
                field.typeText(rowGroup)
                tap(app.alerts.buttons[spanish ? "Guardar" : "Save"])
            }
            tap(app.navigationBars[spanish ? "Editar ejercicio" : "Edit exercise"].buttons["BackButton"])
        }
    }

    private func selectSupersetMembers(in app: XCUIApplication, names: [String] = ["Row", "Press"]) {
        for name in names {
            let toggle = app.switches.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
            XCTAssertTrue(toggle.waitForExistence(timeout: 5), app.debugDescription)
            toggle.switches.firstMatch.tap()
            XCTAssertEqual(toggle.value as? String, "1", toggle.debugDescription)
        }
    }

    private func activateDayAndOpenTrain(in app: XCUIApplication, spanish: Bool = false) {
        tap(app.navigationBars[spanish ? "Editar día" : "Edit day"].buttons["BackButton"])
        let activate = button(spanish ? "Guardar y activar" : "Save and activate", in: app)
        if !activate.exists { tap(app.navigationBars.buttons[spanish ? "Más" : "More"]) }
        tap(activate)
        XCTAssertTrue(
            app.navigationBars[spanish ? "Editar rutina" : "Edit routine"].waitForNonExistence(timeout: 8),
            app.debugDescription)
        tap(app.tabBars.buttons[spanish ? "Entrenar" : "Train"])
        XCTAssertTrue(
            app.navigationBars[spanish ? "Entrenar" : "Train"].waitForExistence(timeout: 5), app.debugDescription)
    }

    private func verifyCustomSetCount(spanish: Bool) {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["HOTFACE_UI_TEST_STORE_ID"] = UUID().uuidString
        app.launchEnvironment["HOTFACE_UI_TEST_ROUTINE_DATE"] = "2026-11-15T12:00:00Z"
        func label(_ english: String, _ spanishLabel: String) -> String { spanish ? spanishLabel : english }
        func press(_ title: String) { tap(button(title, in: app)) }
        func count(_ value: Int) -> String { label("Sets: \(value)", "Series: \(value)") }
        func adjust(_ direction: Int, from value: Int) {
            tap(app.steppers[count(value)].buttons.element(boundBy: direction > 0 ? 1 : 0))
        }
        let toggle = app.switches[label("Custom set count", "Personalizar número de series")]
        func switchCustomCount() { toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap() }
        let editExercise = label("Edit exercise", "Editar ejercicio")
        let editDay = label("Edit day", "Editar día")
        let month = label("November 2026", "Noviembre de 2026")

        launch(app, spanish: spanish)
        press(label("Settings", "Ajustes"))
        press(label("Add gym", "Añadir gimnasio"))
        enter("Gym", in: app.textFields[label("Gym name", "Nombre del gimnasio")])
        press(label("Save", "Guardar"))
        press(label("Routines", "Rutinas"))
        press(label("Add routine", "Añadir rutina"))
        XCTAssertTrue(app.steppers[count(4)].exists)
        adjust(1, from: 4)
        XCTAssertTrue(app.steppers[count(5)].exists)
        press(label("Add day", "Añadir día"))
        press(label("Add exercise", "Añadir ejercicio"))
        enter("Squat", in: app.textFields[label("Exercise name", "Nombre del ejercicio")])
        let initialReps = app.steppers[label("Reps: 10", "Repeticiones: 10")]
        for _ in 0..<5 where !initialReps.isHittable { app.swipeUp() }
        tap(initialReps.buttons.element(boundBy: 0))

        for _ in 0..<5 where !toggle.isHittable { app.swipeUp() }
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertFalse(app.steppers[count(5)].exists)
        XCTAssertFalse(app.staticTexts[count(5)].exists)
        switchCustomCount()
        for _ in 0..<4 where !app.steppers[count(5)].exists { app.swipeUp() }
        XCTAssertTrue(app.steppers[count(5)].exists, app.debugDescription)
        adjust(1, from: 5)
        XCTAssertTrue(app.steppers[count(6)].exists)
        adjust(-1, from: 6)
        XCTAssertTrue(app.steppers[count(5)].exists)
        switchCustomCount()
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertFalse(app.steppers[count(5)].exists)
        tap(app.navigationBars[editExercise].buttons["BackButton"])
        tap(app.navigationBars[editDay].buttons["BackButton"])
        let activate = button(label("Save and activate", "Guardar y activar"), in: app)
        if !activate.exists { tap(app.navigationBars.buttons[label("More", "Más")]) }
        tap(activate)

        app.terminate()
        launch(app, spanish: spanish)
        press(label("Routines", "Rutinas"))
        press(month)
        XCTAssertTrue(app.steppers[count(5)].exists)
        adjust(1, from: 5)
        press(label("Day 1", "Día 1"))
        press("Squat")
        let savedReps = app.steppers[label("Reps: 9", "Repeticiones: 9")]
        for _ in 0..<5 where !savedReps.isHittable { app.swipeUp() }
        XCTAssertTrue(savedReps.exists, app.debugDescription)

        for _ in 0..<5 where !toggle.isHittable { app.swipeUp() }
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertFalse(app.steppers[count(6)].exists)
        switchCustomCount()
        for _ in 0..<4 where !app.steppers[count(6)].exists { app.swipeUp() }
        XCTAssertTrue(app.steppers[count(6)].exists, app.debugDescription)
    }

    func testFailureSegmentReopensInBothLanguages() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["HOTFACE_UI_TEST_STORE_ID"] = UUID().uuidString
        app.launchEnvironment["HOTFACE_UI_TEST_ROUTINE_DATE"] = "2026-11-15T12:00:00Z"
        func press(_ title: String) { tap(button(title, in: app)) }
        func failureOption(spanish: Bool) -> XCUIElement {
            let option = app.segmentedControls.buttons[spanish ? "Fallo" : "To failure"]
            for _ in 0..<4 where !option.exists || !option.isHittable { app.swipeUp() }
            XCTAssertTrue(option.waitForExistence(timeout: 5))
            return option
        }

        launch(app, spanish: false)
        press("Settings")
        press("Add gym")
        enter("Gym", in: app.textFields["Gym name"])
        press("Save")
        press("Routines")
        press("Add routine")
        press("Add day")
        press("Add exercise")
        enter("Push-up", in: app.textFields["Exercise name"])
        let option = failureOption(spanish: false)
        tap(option)
        XCTAssertTrue(option.isSelected)
        XCTAssertFalse(app.staticTexts["Reps: 10"].exists)
        tap(app.navigationBars["Edit exercise"].buttons["BackButton"])
        tap(app.navigationBars["Edit day"].buttons["BackButton"])
        let activate = button("Save and activate", in: app)
        if !activate.exists { tap(app.navigationBars.buttons["More"]) }
        tap(activate)

        func verifySavedFailure(spanish: Bool) {
            press("November 2026")
            press("Day 1")
            press("Push-up")
            XCTAssertTrue(failureOption(spanish: spanish).isSelected)
            XCTAssertFalse(app.staticTexts[spanish ? "Repeticiones: 10" : "Reps: 10"].exists)
        }

        verifySavedFailure(spanish: false)
        app.terminate()
        launch(app, spanish: true)
        press("Rutinas")
        verifySavedFailure(spanish: true)
    }

    func testTrainCompletesSavedSetToFailureWithOneTap() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["HOTFACE_UI_TEST_STORE_ID"] = UUID().uuidString
        func press(_ title: String) { tap(button(title, in: app)) }
        func reveal(_ element: XCUIElement) {
            for _ in 0..<5 where !element.exists || !element.isHittable { app.swipeUp() }
            XCTAssertTrue(element.exists && element.isHittable, app.debugDescription)
        }
        func containsText(_ value: String) -> XCUIElement {
            app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", value)).firstMatch
        }

        launch(app, spanish: false)
        press("Settings")
        press("Add gym")
        enter("Workout Gym", in: app.textFields["Gym name"])
        press("Save")
        press("Routines")
        press("Add routine")
        press("Add day")
        press("Add exercise")
        enter("Push-up", in: app.textFields["Exercise name"])
        let instructions = app.descendants(matching: .any).matching(identifier: "Instructions (optional)")
            .matching(
                NSPredicate(
                    format: "elementType IN %@",
                    [XCUIElement.ElementType.textField.rawValue, XCUIElement.ElementType.textView.rawValue])
            )
            .firstMatch
        reveal(instructions)
        instructions.tap()
        instructions.typeText("Slow lowering")
        enter("A7", in: app.textFields["Station (optional)"])
        reveal(app.segmentedControls.buttons["To failure"])
        tap(app.segmentedControls.buttons["To failure"])
        reveal(button("Equipment", in: app))
        press("Equipment")
        reveal(button("Bodyweight", in: app))
        press("Bodyweight")
        tap(app.navigationBars["Edit exercise"].buttons["BackButton"])
        tap(app.navigationBars["Edit day"].buttons["BackButton"])
        let activate = button("Save and activate", in: app)
        if !activate.exists { tap(app.navigationBars.buttons["More"]) }
        tap(activate)

        press("Train")
        press("Day 1")
        allowWorkoutAccessIfRequested(app)
        for text in ["Push-up", "A7", "Bodyweight", "Slow lowering", "To failure", "Set 1 of 4"] {
            XCTAssertTrue(containsText(text).waitForExistence(timeout: 5), app.debugDescription)
        }
        press("Complete set")
        XCTAssertTrue(containsText("Set 1 completed").waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(containsText("Set 2 of 4").exists)
        XCTAssertTrue(containsText("Rest").exists)
        XCTAssertTrue(button("End rest", in: app).exists)
        XCTAssertFalse(app.textFields["Actual repetitions"].exists)
        XCTAssertFalse(button("Complete set", in: app).exists)

        press("Correct set")
        let count = app.textFields["Actual repetitions"]
        tap(count)
        count.typeText("12")
        press("Save")
        app.terminate()
        launch(app, spanish: false)
        XCTAssertTrue(button("Finish workout", in: app).exists)
        press("Continue workout")
        XCTAssertTrue(containsText("Set 1 completed").waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(containsText("Set 2 of 4").exists)
        press("End rest")
        XCTAssertTrue(containsText("Ready").waitForExistence(timeout: 5))
        XCTAssertTrue(button("Complete set", in: app).exists)
        XCTAssertFalse(containsText("Set 2 completed").exists)
        press("Close")
        press("Finish workout")
        press("Finish workout")
        XCTAssertTrue(containsText("Partially completed").waitForExistence(timeout: 5))
        XCTAssertTrue(containsText("12 reps").exists)
        press("Done")
        XCTAssertFalse(button("Continue workout", in: app).exists)
    }

    func testTimedSetResumesAfterRelaunchAndFinishesEarly() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["HOTFACE_UI_TEST_STORE_ID"] = UUID().uuidString
        func press(_ title: String) { tap(button(title, in: app)) }
        launch(app, spanish: false)
        press("Settings")
        press("Add gym")
        enter("Gym", in: app.textFields["Gym name"])
        press("Save")
        press("Routines")
        press("Add routine")
        press("Add day")
        press("Add exercise")
        enter("Plank", in: app.textFields["Exercise name"])
        let seconds = app.segmentedControls.buttons["Seconds"]
        for _ in 0..<5 where !seconds.isHittable { app.swipeUp() }
        tap(seconds)
        tap(app.navigationBars["Edit exercise"].buttons["BackButton"])
        tap(app.navigationBars["Edit day"].buttons["BackButton"])
        let activate = button("Save and activate", in: app)
        if !activate.exists { tap(app.navigationBars.buttons["More"]) }
        tap(activate)

        press("Train")
        press("Day 1")
        allowWorkoutAccessIfRequested(app)
        verifyActiveHealthSession(in: app, spanish: false)
        press("Start set")
        XCTAssertTrue(app.staticTexts["Get ready"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Exercise"].waitForExistence(timeout: 5))
        press("Pause")
        XCTAssertTrue(app.staticTexts["Paused"].waitForExistence(timeout: 2))
        app.terminate()
        launch(app, spanish: true)
        press("Continuar entrenamiento")
        XCTAssertTrue(app.staticTexts["En pausa"].waitForExistence(timeout: 5))

        press("Reanudar")
        XCTAssertTrue(app.staticTexts["Prepárate"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Ejercicio"].waitForExistence(timeout: 5))
        press("Terminar serie antes de tiempo")
        XCTAssertTrue(app.staticTexts["Serie 1 completada"].waitForExistence(timeout: 5))
        press("Terminar descanso")
        XCTAssertTrue(app.staticTexts["Serie 2 de 4"].waitForExistence(timeout: 5))
        verifyActiveHealthSession(in: app, spanish: true)
        press("Iniciar serie")
        XCTAssertTrue(app.staticTexts["Prepárate"].waitForExistence(timeout: 2))
        press("Cerrar")
        XCTAssertTrue(button("Continuar entrenamiento", in: app).isHittable)
        XCTAssertTrue(button("Editar", in: app).waitForExistence(timeout: 20))
    }

    func testTimedHoldsWaitForManualRestartAndSecondSide() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["HOTFACE_UI_TEST_STORE_ID"] = UUID().uuidString
        func press(_ title: String) { tap(button(title, in: app)) }
        func reveal(_ element: XCUIElement) {
            for _ in 0..<5 where !element.exists || !element.isHittable { app.swipeUp() }
            XCTAssertTrue(element.isHittable, app.debugDescription)
        }
        launch(app, spanish: false)
        press("Settings")
        press("Add gym")
        enter("Gym", in: app.textFields["Gym name"])
        press("Save")
        press("Routines")
        press("Add routine")
        press("Add day")
        press("Add exercise")
        enter("Side plank", in: app.textFields["Exercise name"])
        let perSide = app.switches["Per side"]
        reveal(perSide)
        perSide.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        let seconds = app.segmentedControls.buttons["Seconds"]
        reveal(seconds)
        tap(seconds)
        let add = button("Add segment", in: app)
        reveal(add)
        tap(add)
        let restart = app.switches["Start next hold automatically"]
        reveal(restart)
        XCTAssertEqual(restart.value as? String, "0")
        let pause = app.buttons.matching(identifier: "durationSeconds").matching(
            NSPredicate(format: "label == %@", "Seconds, 0")
        ).firstMatch
        XCTAssertTrue(pause.exists, app.debugDescription)
        tap(pause)
        press("1")
        tap(app.navigationBars["Edit exercise"].buttons["BackButton"])
        tap(app.navigationBars["Edit day"].buttons["BackButton"])
        let activate = button("Save and activate", in: app)
        if !activate.exists { tap(app.navigationBars.buttons["More"]) }
        tap(activate)
        press("Train")
        press("Day 1")
        allowWorkoutAccessIfRequested(app)
        press("Start set")
        XCTAssertTrue(app.staticTexts["Side 1 of 2"].waitForExistence(timeout: 5))
        let next = button("Start next hold", in: app)
        XCTAssertTrue(next.waitForExistence(timeout: 20))
        let enabled = expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: next)
        wait(for: [enabled], timeout: 5)
        tap(next)
        XCTAssertTrue(app.staticTexts["Hold 2 of 2"].waitForExistence(timeout: 5))
        XCTAssertTrue(button("Start second side", in: app).waitForExistence(timeout: 20))
        XCTAssertFalse(app.staticTexts["Rest"].exists)
        press("Start second side")
        press("Finish set early")
        XCTAssertTrue(app.staticTexts["Set 1 completed"].waitForExistence(timeout: 5))
        press("Close")
    }

    private func verifyActiveHealthSession(in app: XCUIApplication, spanish: Bool) {
        let more = app.navigationBars["Day 1"].buttons[spanish ? "Más" : "More"]
        let available = expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: more)
        wait(for: [available], timeout: 8)
        tap(more)
        XCTAssertTrue(
            app.descendants(matching: .any)[spanish ? "Sesión de Salud activa" : "Health session active"].firstMatch
                .waitForExistence(timeout: 5))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.8)).tap()
    }

    private func allowWorkoutAccessIfRequested(_ app: XCUIApplication) {
        let workouts = app.switches["UIA.Health.Write.Workouts.SwitchCell.Switch"]
        if workouts.waitForExistence(timeout: 5) {
            if workouts.value as? String == "0" { workouts.tap() }
            tap(app.buttons["UIA.Health.Allow.Button"])
            XCTAssertTrue(workouts.waitForNonExistence(timeout: 8))
        }
    }

    private func launch(_ app: XCUIApplication, spanish: Bool) {
        app.launchArguments = [
            "-AppleLanguages", spanish ? "(es)" : "(en)", "-AppleLocale", spanish ? "es_CR" : "en_US",
        ]
        app.launch()
    }

    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.exists || element.waitForExistence(timeout: 8), file: file, line: line)
        element.tap()
    }

    private func button(_ title: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@ OR label BEGINSWITH %@", title, title + ","))
            .firstMatch
    }

    private func enter(_ text: String, in field: XCUIElement, replacing existing: String = "") {
        tap(field)
        if !existing.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        }
        field.typeText(text + "\n")
    }

    private func verifySuggestedNames(spanish: Bool) {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["HOTFACE_UI_TEST_STORE_ID"] = UUID().uuidString
        app.launchEnvironment["HOTFACE_UI_TEST_ROUTINE_DATE"] = "2026-11-15T12:00:00Z"
        func label(_ english: String, _ spanishLabel: String) -> String { spanish ? spanishLabel : english }
        func press(_ title: String) { tap(button(title, in: app)) }
        let routineName = app.textFields[label("Routine name", "Nombre de la rutina")]
        let dayName = app.textFields[label("Day name", "Nombre del día")]
        let exerciseName = app.textFields[label("Exercise name", "Nombre del ejercicio")]
        let editDay = label("Edit day", "Editar día")
        let editExercise = label("Edit exercise", "Editar ejercicio")
        let addRoutine = label("Add routine", "Añadir rutina")
        let addDay = label("Add day", "Añadir día")
        let save = label("Save", "Guardar")
        let month = label("November 2026", "Noviembre de 2026")
        let dayOne = label("Day 1", "Día 1")
        let dayTwo = label("Day 2", "Día 2")
        let setCount = app.switches[label("Custom set count", "Personalizar número de series")]
        let restBetween = app.switches[label("Custom rest between sets", "Personalizar descanso entre series")]
        let restAfter = app.switches[label("Custom rest after exercise", "Personalizar descanso tras el ejercicio")]
        let perSide = app.switches[label("Per side", "Por lado")]
        let addSegment = button(label("Add segment", "Añadir segmento"), in: app)
        func reveal(_ element: XCUIElement) {
            for _ in 0..<6 where !element.exists || !element.isHittable {
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.79)).press(
                    forDuration: 0.05,
                    thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.54)))
            }
            XCTAssertTrue(element.exists && element.isHittable, app.debugDescription)
        }
        func enable(_ toggle: XCUIElement) {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
            XCTAssertEqual(toggle.value as? String, "1")
        }
        func configureSegmentsAndOverrides() {
            reveal(setCount)
            XCTAssertTrue(app.staticTexts[label("Sets and rest", "Series y descansos")].exists)
            reveal(restBetween)
            enable(restBetween)
            XCTAssertEqual(setCount.value as? String, "0")
            reveal(restAfter)
            XCTAssertEqual(restAfter.value as? String, "0")
            enable(restAfter)
            XCTAssertEqual(restBetween.value as? String, "1")
            for _ in 0..<4 where !setCount.isHittable { app.swipeDown() }
            enable(setCount)
            reveal(perSide)
            enable(perSide)
            reveal(addSegment)
            tap(addSegment)
            XCTAssertEqual(app.segmentedControls.count, 2)
            XCTAssertEqual(app.switches.matching(identifier: label("Per side", "Por lado")).count, 1)
        }
        func finishDay(_ exercise: String) {
            press(label("Add exercise", "Añadir ejercicio"))
            enter(exercise, in: exerciseName)
            if exercise == "Squat" { configureSegmentsAndOverrides() }
            tap(app.navigationBars[editExercise].buttons["BackButton"])
            tap(app.navigationBars[editDay].buttons["BackButton"])
        }
        func saveAndActivate() {
            let activate = button(label("Save and activate", "Guardar y activar"), in: app)
            if !activate.exists { tap(app.navigationBars.buttons[label("More", "Más")]) }
            tap(activate)
        }

        launch(app, spanish: spanish)
        press(label("Settings", "Ajustes"))
        press(label("Add gym", "Añadir gimnasio"))
        enter("Gym", in: app.textFields[label("Gym name", "Nombre del gimnasio")])
        press(save)
        press(label("Routines", "Rutinas"))
        press(addRoutine)
        XCTAssertEqual(routineName.value as? String, month)
        press(addDay)
        XCTAssertEqual(dayName.value as? String, dayOne)
        enter("Pierna", in: dayName, replacing: dayOne)
        finishDay("Squat")
        press(addDay)
        XCTAssertEqual(dayName.value as? String, dayTwo)
        finishDay("Curl")
        saveAndActivate()

        app.terminate()
        launch(app, spanish: spanish)
        press(label("Routines", "Rutinas"))
        press(month)
        XCTAssertTrue(button("Pierna", in: app).exists)
        XCTAssertTrue(button(dayTwo, in: app).exists)
        press("Pierna")
        press("Squat")
        for toggle in [setCount, restBetween, restAfter, perSide] {
            reveal(toggle)
            XCTAssertEqual(toggle.value as? String, "1")
        }
        reveal(addSegment)
        XCTAssertEqual(app.segmentedControls.count, 2)
        tap(app.navigationBars[editExercise].buttons["BackButton"])
        tap(app.navigationBars[editDay].buttons["BackButton"])
        let mixedCaseName = "fuerza A con un nombre de rutina bastante largo"
        enter(mixedCaseName, in: routineName, replacing: month)
        press(save)

        press(addRoutine)
        press(addDay)
        XCTAssertEqual(dayName.value as? String, dayOne)
        tap(app.navigationBars[editDay].buttons["BackButton"])
        press(label("Cancel", "Cancelar"))

        let original = button(mixedCaseName, in: app)
        XCTAssertTrue(original.waitForExistence(timeout: 8))
        XCTAssertGreaterThan(original.frame.width, app.frame.width * 0.75)
        XCTAssertFalse(button(label("Routine actions", "Acciones de la rutina"), in: app).exists)
        original.swipeLeft()
        press(label("Archive routine", "Archivar rutina"))
        XCTAssertTrue(app.staticTexts[label("Archive routine?", "¿Archivar la rutina?")].exists)
        press(label("Cancel", "Cancelar"))
        tap(original)
        XCTAssertEqual(routineName.value as? String, mixedCaseName)
        press(label("Cancel", "Cancelar"))
        original.swipeLeft()
        press(label("Copy routine", "Copiar rutina"))
        let copyName = label("Copy of ", "Copia de ") + mixedCaseName
        XCTAssertEqual(routineName.value as? String, copyName)
        saveAndActivate()

        app.terminate()
        launch(app, spanish: spanish)
        press(label("Routines", "Rutinas"))
        press(copyName)
        XCTAssertEqual(routineName.value as? String, copyName)
    }
}
