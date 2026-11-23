# Tasks

## 1. iPhone feasibility

- [x] 1.1 Inspect Xcode, the SDK and both device versions. Record iOS 26 compatibility and list signing requirements.
- [x] 1.2 Create a minimal test app and Live Activity extension. Verify build and launch in the simulator using test data.
- [x] 1.3 Test AlarmKit, ActivityKit and App Intents on iPhone for completing a set, starting, pausing, resuming, three seconds of preparation and automatic transition to rest. Document observable results and permissions.
- [x] 1.4 Test distinct cues, holds, music and headphones while locked and when switching apps. Record separate results for normal locking, force quit and restart.
- [x] 1.5 Validate SwiftData and shared app/extension storage with two concurrent actions and recovery. Demonstrate that no set is lost or duplicated.
- [x] 1.6 Compare feasibility results with workout-timers. If an agreed requirement is infeasible, present the evidence and resolve it with the user before implementation.

## 2. Application and data foundations

- [x] 2.1 Create domain, repository, adapter and interface modules. Verify the build and test a transition without the UI.
- [x] 2.2 Define versioned entities and session snapshots. Verify saving and reloading, and that routine edits preserve historical sessions.
- [x] 2.3 Implement persistent, idempotent session commands. Test double taps and recovery after each critical transition.
- [x] 2.4 Add English and Spanish String Catalogs to the app and extensions. Verify language selection and decimal and date formatting while preserving kg/lb units and custom text.
- [x] 2.5 Implement Train, Routines, History and Settings navigation and empty states. Walk through them in both languages with Dynamic Type and document how to run the tests.

## 3. Gyms, equipment and the first routine

Continue 3.1 with 3.11 (model and migration) and 3.12 (Settings). Use the resulting catalog in 3.2 and 3.3 before integrating the picker in 3.5.

- [x] 3.1 Implement gym and equipment profiles with available loads. Verify creation, editing and independent selection per gym.
- [x] 3.2 Implement selection of individual dumbbells, fixed bars and the 30 selectorized-machine loads from 5 to 150 kg in 5 kg steps. Test 10 lb and 10 kg in one inventory, one and two dumbbells, total fixed-bar weight and round-trip conversions between per-implement, total and per-side views that preserve physical load and progression balance.
- [x] 3.3 Calculate reachable symmetric loads using shared, repeatable plate sizes. Test 30 versus 31 lb added, removing small sizes, accepting 500 and rejecting 505 lb, and enforcing a lower machine-specific per-side limit. Exclude equipment weight from limits and progression percentages.
- [x] 3.4 Implement undefined, estimated and confirmed load states. Verify that using an estimate leaves it estimated and that zero is distinct from a missing load.
- [x] 3.5 Build the manual editor for routines, days, exercises, variants, segments and rest, with load selection by gym and equipment. Enter a routine with a timed exercise, per-side repetitions and 7+7+7. Verify that two exercises use the same inventory and save independent usual loads.
- [x] 3.5.1 Add the routine set count beside the rest settings and an optional per-exercise override in both editor languages. Start new routines at 4 sets. Test changing the default from 3 to 4 across days, retaining explicit overrides even when equal to the old default, and restoring inheritance after reopening. Verify session snapshots and reopen a frozen pre-inheritance fixture to check that existing exercise counts become overrides.
- [x] 3.5.2 Group the day editor’s exercise list by optional group and retain manual order within each group. Verify a single named group, all exercises unassigned, multiple named groups, and a named group alongside unassigned exercises. Check heading visibility and the localized unassigned heading in English and Spanish.
- [x] 3.6 Implement activation, copying and archiving. Test switching gyms and returning with a new routine, zero balances and preserved history.
- [x] 3.7 Implement cycles and temporary or usual day order. Test skipped days, different dates, cycle completion and availability in the next cycle.
- [x] 3.8 Document and verify the flow from editable initial gym inventories to choosing a load per exercise in the first routine without importing Markdown.
- [x] 3.9 Query the last actual load locally by gym and exercise name. Test multiple archived routines, a partial session, a later skip, a zero load and a newer record from another gym.
- [x] 3.10 Integrate the suggestion into the new-routine editor. Verify the comparison of 4 × (7+7+7) with 3 × 8, the date, load, unit and available station and instructions, omitting the gym name. Test confirming, editing, leaving the load undefined and keeping a copied load.
- [x] 3.11 Persist the three shared inventories per gym with units per entry and initial values from gym-equipment. Migrate the catalogs from 3.1. Reopen a frozen V3 store with two equipment items sharing sizes and verify deduplication, units, base weights, gym selection and history. Retain earlier fixtures.
- [x] 3.12 Update Settings to edit the three inventories once per gym, the barbell base weight (initially 45 lb) and the optional per-side maximum for barbells and plate-loaded machines. Verify mixed-unit editing in Spanish and English, that removed weights stay absent after reopening and that another gym keeps its values.

- [x] 3.13 Implement gym deletion in the repository and Settings. Cover an inactive gym, replacement of the active gym, an open session and deletion of the last gym. After reopening the store, verify routine archiving, the empty state, a new identity when reusing a name and access to history.
- [x] 3.14 Implement equipment deletion in the repository, Settings and pickers. Show a deleted assignment in the routine editor and allow replacement. After reopening, verify that shared inventories and equipment in other gyms retain their values, that an open session can finish and that history retains the station, loads and units.
- [x] 3.15 Test confirmation and cancellation of both deletion flows in the simulator in Spanish and English. Check the item name, its gym when applicable, the stated effects and that cancellation preserves the original selection, routine and assignments.

- [x] 3.16 Add day-owned groups and a group picker to the exercise editor. Verify creating, reusing and clearing a group, matching names regardless of case or surrounding whitespace, and retaining an empty group in the picker after reopening. Reopen a frozen routine from the free-text editor and verify deduplication within each day, independent groups across days, exercise order and heading visibility.
- [x] 3.17 Offer one generic option for each of the eight equipment types in new and existing gyms. In the exercise editor, choose a load using the gym's inventory, add specific equipment and assign it to just one exercise. Reopen a frozen pre-change gym and verify that all eight options appear once and that custom equipment, edited weights, existing assignments and historical sessions are preserved.
- [x] 3.18 Add the 13-color resistance band picker for generic and specific bands, with a swatch and localized name for each color. Save different colors for two exercises using the same equipment and verify both after reopening in English and Spanish. Check that older prescriptions with numeric resistance retain their load and have no preselected color.

- [ ] 3.19 Prefill editable names for new routines, copies and days in both interface languages. With the clock set to November 2026, verify “November 2026” and “noviembre de 2026”. Copy “Fuerza” and verify “Copy of Fuerza” and “Copia de Fuerza”. Rename the first day, add a second and check that numbering continues with “Day 2” or “Día 2” and starts at one in another routine. Save and reopen routines with both suggested and edited names.
- [ ] 3.20 Add “To failure” (“Fallo”) alongside repetitions and seconds in the exercise segment editor. Allow saving it without a numeric target and verify the selected option after reopening in both languages. Reopen a frozen routine from the previous format and verify its repetition and timed segments.

- [ ] 3.21 Retain the exercise's usual load when switching between generic or specific equipment of the same type. Test an exact match after saving and reopening, including its unit, representation and estimated or confirmed state. Verify selection of the closest available weight when the exact load is unavailable, including a tie resolved to the lighter weight. Check that an undefined load remains undefined.

- [ ] 3.22 Group the set count and both rest controls in one exercise editor section. Move the exercise-wide “Per side” toggle into the segments section. In both languages, verify that each override can be set independently and that a multi-segment exercise shows one toggle and retains its settings after reopening.

- [ ] 3.23 Move Copy and Archive into left-swipe actions on editable routine rows. Verify that a long name uses the space previously occupied by the actions label, tapping it opens the original, Copy opens a new draft and Archive requires confirmation. Update the month-name expectation from 3.19 to “Noviembre de 2026” in Spanish and verify “November 2026” in English. Save and reopen a user-entered name with mixed capitalization.

## 4. End-to-end basic training

### First delivery after group 3

From this point, start each new tab flow with an interactive prototype using sample data. Test it with the user, refine the UI and then integrate the logic and storage. Apply the same approach when an existing tab gains functionality such as progression suggestions or export.

- [ ] 4.0.1 Create the interactive Train flow for an unlocked iPhone. Preload one day from rutina1 or rutina3 in memory with sample loads. On iPhone, start the day, inspect the load and prescription, complete a set with one tap, correct it during rest, advance to the next exercise and verify the correction in the summary. Try two sets prescribed to failure, entering a count during the first rest and leaving the second count blank. Refine the UI with the user after the walkthrough.
- [ ] 4.0.2 Once the unlocked flow is defined, test the lock-screen experience with the user using the same sample session. Complete a set, check the rest timer and return to the app to see which set is next. Refine visible information and controls before integration in 5.6.

### Workout integration

Once both flows are defined, connect the agreed screens to the domain, persistence and timers through tasks 4.1–4.7 and the corresponding tasks in group 5.

- [ ] 4.1 Implement the set screen with exercise name, station, equipment and instructions. Verify that Complete records the values and starts rest with one tap. For a set prescribed to failure, show the prescription and verify that the same tap completes the set and starts the applicable rest without prompting for a repetition count.
- [ ] 4.2 Implement set correction during rest and sets that include both sides. During rest after a set performed to failure, allow entry of the actual repetitions for that set. Reopen a session with two completed sets and verify that a count entered for one persists while the other count remains unspecified. Verify that corrections preserve the usual routine and do not duplicate sets.
- [ ] 4.3 Implement temporary changes, reuse of adjustments and explicit saving as usual settings. Verify persistence only within the chosen scope.
- [ ] 4.4 Implement adding, replacing, postponing, selecting and skipping exercises. Test an occupied station, returning to the exercise and preserving the usual order. Verify that the Train exercise list uses the day editor’s group headings, including the unassigned group and single-group rule, and that opening the grouped list preserves the next exercise in session order.
- [ ] 4.5 Implement full and partial session completion and the summary. Verify retention of sets and ratings, pending exercises recorded as unperformed, the day marked complete and no final rest. In the summary, verify that two sets performed to failure both appear as completed when only one has a recorded repetition count.
- [ ] 4.6 Implement open-session recovery. Test unexpected termination and reopening on another date with options to continue or finish.
- [ ] 4.7 Complete a cycle offline and review history. Deliver an integration test and a short guide distinguishing a partially completed session from an open session.

## 5. Timers, audio and supersets

- [ ] 5.1 Integrate the validated timing solution with persisted states and an injectable clock. Test pauses, three seconds of preparation, early completion and remaining time.
- [ ] 5.2 Implement rests of 1:45 and 2:15 with routine, exercise and superset settings, ±15-second adjustments and early completion. Test that adjustments preserve future defaults and never produce negative times.
- [ ] 5.3 Implement transitions to the next set or exercise in a waiting state. Verify expiration outside the app and that the next activity starts only when requested.
- [ ] 5.4 Implement per-side timing, holds and configurable restart. Test the cue and transition after the first side and rest only after both sides.
- [ ] 5.5 Implement creation and dissolution of usual and temporary supersets. Test rounds, equal set counts, mixed prescriptions and preservation of progress when dissolving a superset.
- [ ] 5.6 Integrate localized lock-screen controls and cues. Verify a real session with music and headphones and with permissions granted and denied. Verify that inoperative controls do not report success.
- [ ] 5.7 Document verified capabilities, system limits and permission steps. Cross-check the guide against the device matrix.

## 6. Progression and ratings

- [ ] 6.1 Implement a capped balance and optional ratings for complete and partial exercises. Test cancellation, limits, missing ratings and temporary adjustments.
- [ ] 6.2 Implement resets for changes to usual settings and exercise replacements. Verify that notes, order and load representation preserve the balance.
- [ ] 6.3 Implement weight suggestions using the same loads the editor offers for the gym and equipment. Test the inclusive 10% threshold, zero load, limited inventory and increases from 50 to 52.5 and 50 to 55 with repetitions preserved. Verify that the engine excludes unreachable plate loads and loads above the equipment limit.
- [ ] 6.4 Implement the repetition bridge separately from the balance. Test 35×10 → 35×12 → 45×10 and a return to 12 after bridging to 15.
- [ ] 6.5 Implement upward and downward steps, the case of 15 repetitions without a bridge, and limits where no higher or lower load exists. Test 9 → 10 or 8, a minimum of 6, and manual adjustment for timed and combined exercises.
- [ ] 6.6 Review the proposed bridge invalidation policy with the user for edits to a suggestion. Document the decision and cover it with tests before implementing that case.
- [ ] 6.7 Integrate an editable suggestion at exercise start with confirmation to save it as usual. Test repeated rejection, customized acceptance, balance reset and the reason in both languages.

## 7. History, notes and CSV

- [ ] 7.0 First test the History flow using fixtures for one complete and one partial session. Open a session and review its sets and loads with the user. Refine the UI before connecting the queries and actions in group 7.
- [ ] 7.1 Implement queries for sessions, progress and personal records with explicit units. Verify partial sessions and comparisons that distinguish equipment and gyms. Open a past workout with two sets performed to failure and verify that history shows both as complete, one with its recorded repetitions and the other with an unspecified count.
- [ ] 7.2 Record changes to usual prescriptions with their date and previous and new values. Test edited suggestions, replacements and archiving while preserving historical records.
- [ ] 7.3 Implement dated notes with editing, deletion, undo and redo. Verify the scope of undo during editing.
- [ ] 7.4 Implement CSV export of workouts and changes. Test special characters, multiline text, mixed units, zero versus missing values and relationships between rows.
- [ ] 7.5 Document CSV columns and formats. Verify that a sample export has the same interpretation from the Spanish and English interfaces.

## 8. Private backup and restore

- [ ] 8.0 Test the new backup and restore flows in Settings using sample dates and states. Review with the user how they identify the latest backup and choose one to restore. Refine the flow before connecting CloudKit.
- [ ] 8.1 Configure CloudKit capabilities and the private container once membership is available. Verify separate access with both test accounts.
- [ ] 8.2 Implement a consistent versioned snapshot, asset uploads and a final manifest. Test network interruption and verify that an incomplete backup is never published.
- [ ] 8.3 Implement automatic retry and the latest backup status. Test a missing account, quota limits, offline use and reconnection without blocking sessions.
- [ ] 8.4 Implement restoration to a temporary store and validated replacement. Test a corrupt backup, an older schema and preservation of local data on failure.
- [ ] 8.5 Define and document retention and account switching. Verify isolation between users and that a valid backup is always preserved during renewal.

## 9. Photo import and review

- [ ] 9.0 Test review of a preloaded draft in Routines based on the analyzed photos. Walk through the days, correct a prescription and inspect the result in the editor using sample data. Refine the UI with the user before integrating extraction and saving.
- [ ] 9.1 Define a structured extraction contract and reviewable draft. Validate synthetic examples covering both sides of the sheet, uncertain fields and combined repetitions.
- [ ] 9.2 Evaluate the visual extraction provider, cost and image handling. Deliver a comparison and make a selection before enabling paid services.
- [ ] 9.3 Implement a minimal authenticated service and adapter. Keep keys out of the client and images out of logs. Test invalid requests, limits, timeouts and retries.
- [ ] 9.4 Evaluate extraction with rutina1 and rutina3 as authorized local samples. Verify differing legends, numbering, a crossed-out station, uncolored handwritten entries and the distinction between MAQ and load.
- [ ] 9.5 Implement editable review by day with an image reference. Verify corrections to order, names, times, per-side indications (“c/u”) and segments before saving.
- [ ] 9.6 Implement the configurable gym convention that tentatively assigns abdominal exercises without a day to Day 1 for confirmation. Test that an explicit day takes priority and that other gyms do not use the convention by default.
- [ ] 9.7 Integrate the imported draft with the routine editor and manual supersets. Verify that a missing load is filled only through user input or confirmation of a historical suggestion. Complete import → edit → offline training and document what to review.

## 10. Distribution and integrated verification

- [ ] 10.1 Prepare Ad Hoc signing, register both devices and document expiration and renewal. Verify private installation with a stable identity.
- [ ] 10.2 Validate production iCloud in the distributed build. Restore each account’s test data and verify isolation between accounts.
- [ ] 10.3 Run create/import → partial workout → recover → finish → progress → back up → export on both iPhones in Spanish and English. Record evidence and failures.
- [ ] 10.4 Test updating over a previous installation with test data and schema migration. Verify preservation of history and the documented recovery procedure.
- [ ] 10.5 Review all scenarios in the eight specifications and the audio/lock-screen matrix. Report actual results and outstanding limitations, distinguishing simulator-only evidence from physical-device verification.
