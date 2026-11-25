import XCTest

@MainActor
final class RoutineEditorUITests: XCTestCase {
    func testSuggestedNamesInEnglish() { verifySuggestedNames(spanish: false) }
    func testSuggestedNamesInSpanish() { verifySuggestedNames(spanish: true) }
    func testCustomSetCountInEnglish() { verifyCustomSetCount(spanish: false) }
    func testCustomSetCountInSpanish() { verifyCustomSetCount(spanish: true) }

    func testCreateUsualSupersetAndDissolveForThisWorkout() {
        continueAfterFailure = false
        let app = XCUIApplication()
        func press(_ title: String) { tap(button(title, in: app)) }

        createDayWithTwoExercises(in: app)
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
        createDayWithTwoExercises(in: app)
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

    private func createDayWithTwoExercises(in app: XCUIApplication) {
        app.launchEnvironment["HOTFACE_UI_TEST_STORE_ID"] = UUID().uuidString
        func press(_ title: String) { tap(button(title, in: app)) }
        launch(app, spanish: false)
        press("Settings")
        XCTAssertTrue(app.staticTexts["No gym configured"].waitForExistence(timeout: 5), app.debugDescription)
        press("Add gym")
        enter("Gym", in: app.textFields["Gym name"])
        press("Save")
        press("Routines")
        press("Add routine")
        press("Add day")
        for name in ["Row", "Press"] {
            press("Add exercise")
            let field = app.textFields["Exercise name"]
            tap(field)
            if !app.keyboards.firstMatch.waitForExistence(timeout: 2) { tap(field) }
            field.typeText(name + "\n")
            tap(app.navigationBars["Edit exercise"].buttons["BackButton"])
        }
    }

    private func selectSupersetMembers(in app: XCUIApplication) {
        for name in ["Row", "Press"] {
            let toggle = app.switches.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
            XCTAssertTrue(toggle.waitForExistence(timeout: 5), app.debugDescription)
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        }
    }

    private func activateDayAndOpenTrain(in app: XCUIApplication) {
        tap(app.navigationBars["Edit day"].buttons["BackButton"])
        let activate = button("Save and activate", in: app)
        if !activate.exists { tap(app.navigationBars.buttons["More"]) }
        tap(activate)
        XCTAssertTrue(app.navigationBars["Edit routine"].waitForNonExistence(timeout: 8), app.debugDescription)
        tap(app.tabBars.buttons["Train"])
        XCTAssertTrue(app.navigationBars["Train"].waitForExistence(timeout: 5), app.debugDescription)
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
        XCTAssertFalse(app.staticTexts["Reps: 8"].exists)
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
            XCTAssertFalse(app.staticTexts[spanish ? "Repeticiones: 8" : "Reps: 8"].exists)
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
        let pause = app.steppers["Pause between holds: 0 s"]
        tap(pause.buttons.element(boundBy: 1))
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
