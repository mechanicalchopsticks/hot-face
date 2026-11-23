## Purpose

Organize personal routines into training days and cycles that run independently of calendar dates, and retain archived versions.

## ADDED Requirements

### Requirement: Active routine and routine creation
The app SHALL support manually creating, editing and copying routines with reorderable days and grouped exercises. Only one routine SHALL be active at a time.

#### Scenario: Copy a previous routine
- **WHEN** the user copies and activates an archived routine
- **THEN** the copy retains its structure and settings and starts with a fresh history and new progression balances
- **AND** the original remains intact and the previously active routine is archived with its history

### Requirement: Editable default names for routines and days
When the user adds a routine, the editor SHALL prefill its name with the current month and year in the interface language. When the user copies a routine, the editor SHALL prefill the copy's name with the localized prefix “Copy of ” (“Copia de ” in Spanish) followed by the original name. Each routine SHALL number its added days in order starting at one, using “Day {number}” in English and “Día {number}” in Spanish. The user SHALL be able to accept or edit each suggested name before saving.

#### Scenario: Add a routine in November 2026
- **WHEN** the user opens Add Routine in November 2026
- **THEN** the name field contains “noviembre de 2026” in Spanish or “November 2026” in English
- **AND** saving with the suggested name retains that name

#### Scenario: Copy a named routine
- **WHEN** the user copies a routine named “Fuerza”
- **THEN** the name field contains “Copia de Fuerza” in Spanish or “Copy of Fuerza” in English

#### Scenario: Add days after renaming the first day
- **WHEN** the user adds the first day to a routine in Spanish, renames “Día 1” to “Pierna” and adds a second day
- **THEN** the second day's name field contains “Día 2” and the first day keeps the name “Pierna”
- **AND** the first day added to another new routine starts as “Día 1”

### Requirement: Exercise editor sections
The exercise editor SHALL group the controls for set count, rest between sets and rest after the exercise in one section. Each control SHALL allow an independent choice between the routine default and an exercise override. The editor SHALL place a single “Per side” toggle in the section listing the segments in each set. The toggle SHALL apply to the whole exercise.

#### Scenario: Edit a multi-segment exercise
- **WHEN** the user opens an exercise with two segments
- **THEN** the set count and both rest controls appear together
- **AND** the user can override rest between sets while inheriting the routine's set count and rest after the exercise
- **AND** the segment list contains one “Per side” toggle for both segments

### Requirement: Exercise segments prescribed to failure
For each exercise segment, the editor SHALL offer “To failure” (“Fallo” in Spanish) alongside repetitions and seconds. This option SHALL prescribe as many repetitions as possible without a numeric target.

#### Scenario: Prescribe a segment to failure
- **WHEN** the user selects “Fallo” for an exercise segment in Spanish
- **THEN** the user can save the prescription without entering a quantity for that segment
- **AND** reopening the exercise shows “Fallo” for that segment

### Requirement: Exercise groups in the day editor
The day editor SHALL group the day's exercises by their optional group and preserve their manual order within each group. Exercises without an assigned group SHALL count as one group. The list SHALL show a heading for each group only when at least two groups are visible. Named groups SHALL use their user-entered names. The unassigned group SHALL use the localized heading “Ungrouped” (“Sin grupo” in Spanish).

#### Scenario: A day contains a single group
- **WHEN** all exercises in the day belong to the same named group, or all are unassigned
- **THEN** the editor shows the exercises in their manual order without a group heading

#### Scenario: A day contains named and unassigned exercises
- **WHEN** a day contains a squat and a lunge assigned to “Pierna” and an unassigned walk
- **THEN** the Spanish editor shows the squat and lunge under “Pierna” in their manual order and the walk under “Sin grupo”

### Requirement: Reusable groups within a training day
Each day SHALL own its named groups. When creating or editing an exercise, the user SHALL be able to leave it unassigned, select an existing group from that day or create a group and assign it immediately. Name matching SHALL ignore capitalization and surrounding whitespace and preserve the existing group's display name. A group with no exercises SHALL remain available in that day's picker and SHALL be omitted from the exercise list and its visible group count.

#### Scenario: Reuse a group while editing another exercise
- **WHEN** one exercise belongs to “Pierna” and the user selects that group for another exercise or enters “ pierna ” as a new group name
- **THEN** both exercises belong to the existing “Pierna” group and the picker lists it once

#### Scenario: Reassign the last member
- **WHEN** the user moves the last member of “Core” to the unassigned group and reopens the routine
- **THEN** “Core” is absent from the exercise list but can be selected again in that day's exercise editor
- **AND** an independently created group with the same name on another day retains its members

#### Scenario: Open a day saved with free-text groups
- **WHEN** a previously saved day has exercises labeled “Pierna” and “ pierna ” interleaved with an unassigned exercise
- **THEN** the editor offers a single “Pierna” group for that day, using the first matching name in exercise order with surrounding whitespace removed
- **AND** blank labels are unassigned, and saving and reopening preserves the original exercise sequence and group assignments

### Requirement: Routine set count and exercise overrides
The routine editor SHALL offer a default set count alongside the rest settings. A new routine SHALL start with a default of 4 sets. Each new manual exercise SHALL inherit the current routine default. The exercise editor SHALL show the effective count and allow the user to set an individual override or return to the routine default. Both the default and the override SHALL be positive whole numbers.

#### Scenario: Change the routine default across training days
- **WHEN** the user changes the routine default from 3 sets to 4
- **THEN** every exercise that inherits the default shows 4 sets across all days, including exercises already in the routine
- **AND** an exercise with an individual override of 5 sets keeps 5 after saving and reopening the routine

#### Scenario: Keep an explicit override even when it matches the default
- **WHEN** the user explicitly sets an exercise to 3 sets while the routine default is 3 and later changes the default to 4
- **THEN** the exercise keeps its override of 3 sets

#### Scenario: Return an exercise to the routine default
- **WHEN** the user clears an exercise override while the routine default is 4 sets
- **THEN** the exercise immediately shows 4 sets
- **AND** after saving and reopening the routine, the exercise follows subsequent changes to the default

#### Scenario: Open a routine saved before set inheritance was available
- **WHEN** the user opens a previously saved routine that contains only individual exercise set counts
- **THEN** the routine default is 1 and each stored exercise count is preserved as an explicit override, including counts of 1
- **AND** the user can return any exercise to the routine default independently

#### Scenario: Preserve the set counts prescribed at session start
- **WHEN** a session starts with a routine default of 3 sets and an exercise override of 5 sets
- **THEN** the session records 3 sets for an inheriting exercise and 5 for the exercise with the override
- **AND** later routine edits preserve those counts in the open session and its history

### Requirement: Cycles independent of calendar dates
The app SHALL complete a cycle once all days have been completed or skipped and make all days available again at the start of the next cycle.

#### Scenario: Skip a day
- **WHEN** the user skips one day and finishes the others on different dates
- **THEN** the cycle ends and the skipped day is available again in the next cycle

#### Scenario: Finish a partial session
- **WHEN** the user finishes a session with exercises still pending
- **THEN** the day counts as completed in the cycle and the pending exercises do not carry over to another day

### Requirement: Temporary day order
Changes to day order SHALL apply only to the current cycle unless the user explicitly chooses to keep them for future cycles.

#### Scenario: Reorder days for the current cycle
- **WHEN** the user moves Day 3 ahead of Day 2 for the current cycle
- **THEN** the next cycle uses the previous usual order

### Requirement: Manual routine renewal
The app SHALL keep the routine active between cycles until the user replaces it or changes gyms.

#### Scenario: Finish a cycle
- **WHEN** the user finishes the last day of the cycle
- **THEN** the routine remains active
