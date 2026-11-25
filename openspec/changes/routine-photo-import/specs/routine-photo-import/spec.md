## Purpose

Turn both sides of a paper workout sheet into an editable routine draft while exposing uncertain interpretations before anything is saved.

## ADDED Requirements

### Requirement: Joint extraction from two photos
The app SHALL combine printed text, handwriting, colors, and numbering from both selected photos into one draft. Import SHALL be allowed to require a connection without blocking training.

#### Scenario: A day spans both sides
- **WHEN** a day's exercises appear across both photos
- **THEN** the draft groups them under the same day and orders them using the handwritten numbering

### Requirement: Sheet-specific color legend
The app SHALL derive each sheet's own color-to-day mapping instead of applying a universal mapping.

#### Scenario: Orange identifies different days
- **WHEN** orange represents Day 4 in one sheet and Day 2 in another
- **THEN** each import uses its own legend

### Requirement: Review before saving
The app SHALL make all imported fields editable and flag uncertain text, crossed-out data, missing order, and unassigned days before saving. It SHALL not invent loads or interpret a station label as a load.

#### Scenario: Crossed-out station
- **WHEN** a station label is crossed out or illegible
- **THEN** the draft flags the station for review instead of silently copying a value from another sheet

#### Scenario: Day known but order missing
- **WHEN** an exercise has a day color but no number
- **THEN** the draft assigns its day and leaves its order for review

### Requirement: Gym-specific abdominal convention
For the gym associated with the sample sheets, the app SHALL tentatively assign abdominal exercises without a day to Day 1 and require confirmation. An explicit day SHALL take priority, and the convention SHALL not apply to other gyms by default.

#### Scenario: Missing color on abdominal work
- **WHEN** an abdominal exercise has no day color in that gym
- **THEN** the draft includes it as a Day 1 candidate marked for confirmation

### Requirement: Faithful prescriptions
The app SHALL distinguish seconds, per-side repetitions, and combined segments, and SHALL preserve variants and instructions for review. It SHALL present ambiguous general notes without inventing their distribution.

#### Scenario: Mixed prescription formats
- **WHEN** the sheet contains a duration, per-side repetitions, and a 7+7+7 segment
- **THEN** the draft preserves the three forms and their instructions separately

#### Scenario: General cardio note
- **WHEN** the sheet says to do at least 15 minutes of cardio every day
- **THEN** the draft presents that instruction for review across days without inventing equipment or session position

### Requirement: Confirmed routine creation
Saving an import SHALL use the reviewed draft in the routine editor. Missing loads SHALL remain undefined until entered or a historical suggestion is confirmed, and supersets SHALL be available for manual definition.

#### Scenario: Save a draft with a missing load
- **WHEN** the user saves a reviewed exercise without entering or confirming a load
- **THEN** the exercise retains an undefined load in the created routine
