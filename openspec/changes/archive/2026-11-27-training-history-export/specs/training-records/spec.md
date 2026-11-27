## Purpose

Preserve and present what users actually performed, how their usual prescriptions changed, and portable records for analysis outside the app.

## ADDED Requirements

### Requirement: Faithful workout history
The app SHALL show complete and partial sessions, performed sets and values, skipped work, and their routine and gym context without rewriting sessions after a routine edit.

#### Scenario: Review a partial session
- **WHEN** a user opens a session finished before all prescribed work was done
- **THEN** the history distinguishes performed sets from unperformed work and shows retained ratings

#### Scenario: Review total session duration
- **WHEN** a user views a complete or partial session in the History list or opens its detail
- **THEN** both views show the elapsed time from the recorded start to finish, including rests, in minutes and two-digit seconds

#### Scenario: Review band resistance
- **WHEN** a user opens a session that prescribed a specific resistance band color
- **THEN** the session detail shows the saved color in the interface language

#### Scenario: Review sets performed to failure
- **WHEN** two sets prescribed to failure were completed and repetitions were entered for only one
- **THEN** both appear complete, with the recorded count on one and an unspecified count on the other

### Requirement: Progress and personal records
The app SHALL let users review progress and personal records with explicit load units and gym and equipment context.

#### Scenario: Compare recorded loads
- **WHEN** a user reviews records made with different gyms or equipment
- **THEN** the app keeps those contexts distinct and displays the recorded units

#### Scenario: Review a measured repetition sequence
- **WHEN** a set contains multiple repetition segments
- **THEN** the repetition record uses their total when every segment has a measured count and excludes sets with an unspecified count

### Requirement: Usual prescription change history
The app SHALL record dated previous and final values when usual weight, sets, repetitions, duration, or exercise selection changes.

#### Scenario: Accept an edited suggestion
- **WHEN** a user edits and accepts a progression suggestion
- **THEN** history shows the former usual values and the values actually confirmed, including a single acceptance record when those values match

#### Scenario: Edit the exercises in a saved routine
- **WHEN** the routine editor saves a removed exercise and a newly added exercise
- **THEN** History and the CSV identify the removed prescription and the added prescription independently

#### Scenario: Change only the load display
- **WHEN** a user saves an equivalent representation of the same physical load
- **THEN** the exercise retains the selected display and the change history and effort balance stay the same

#### Scenario: Review reassigned equipment
- **WHEN** the equipment assignment changes
- **THEN** History identifies the equipment on each side and uses its saved identifier when an item is unavailable

### Requirement: Editable dated notes
The app SHALL save dated notes and allow editing and deletion, with undo and redo during the current edit.

#### Scenario: Undo a note edit
- **WHEN** a user edits a note and selects Undo before leaving the editor
- **THEN** the previous text returns and the user can redo the edit

### Requirement: CSV export
The app SHALL export workouts and usual prescription changes with stable column identifiers, unambiguous dates, explicit units, and relational identifiers. Missing values SHALL remain distinct from zero.

#### Scenario: Export a partial session
- **WHEN** a user exports a partial session and its change history
- **THEN** the files represent completed sets, omissions, old and new values, and missing values without substituting zero

#### Scenario: Change interface language
- **WHEN** a user exports the same records from Spanish and English interfaces
- **THEN** the column identifiers and meaning of the exported values remain the same
