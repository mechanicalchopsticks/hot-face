## Purpose

Guide workouts offline and save progress while distinguishing the usual prescription from what the user actually performed.

## ADDED Requirements

### Requirement: Fully offline workouts
The app SHALL support starting, logging, adjusting, recovering and finishing workouts offline. The screen SHALL show the current exercise, its station when available, equipment, instructions and current set prescription.

#### Scenario: Train offline
- **WHEN** the user trains offline
- **THEN** all progress is saved locally and a pending backup does not block the session

### Requirement: Quick set logging
One tap on Complete Set SHALL record the displayed values and start the applicable rest. The user SHALL be able to correct the set during rest. A per-side set SHALL include both sides.

#### Scenario: Per-side repetitions
- **WHEN** the user finishes 10 repetitions on each side and taps Complete Set
- **THEN** the app records one set of 10 repetitions per side and starts the rest

### Requirement: Session adjustments
The app SHALL allow the user to change the weight, set count, repetitions, duration or exercise, reuse previous temporary adjustments and add exercises from any group. Adjustments SHALL apply only to the session unless the user explicitly saves them as usual settings.

#### Scenario: Add an exercise
- **WHEN** the user adds an exercise during a workout without saving it as usual
- **THEN** the exercise appears in the session and its history and is absent from the next cycle

#### Scenario: Save a replacement
- **WHEN** the user saves a replacement as usual
- **THEN** the app records the permanent change and resets the exercise’s effort balance

### Requirement: Exercise order and skips
The app SHALL allow the user to postpone an exercise, select another pending exercise, return to the postponed exercise and skip exercises. Changes to session order SHALL preserve the usual order.

#### Scenario: An occupied station
- **WHEN** the user postpones an exercise, performs another and returns to the first
- **THEN** the app retains progress for both exercises without recording a routine change

### Requirement: Exercise groups in the Train list
Train lists for selecting, postponing or reordering exercises SHALL use the day editor’s group headings: one heading per visible group when at least two are present, counting unassigned exercises as one localized “Ungrouped” section. The list SHALL preserve session order within each group and SHALL leave the next exercise determined by the session sequence.

#### Scenario: Show groups while keeping the next exercise in session order
- **WHEN** the Spanish Train list opens with a squat, a walk and a lunge in session order, with the squat and lunge assigned to “Pierna” and the walk unassigned
- **THEN** the list shows the squat and lunge under “Pierna” and the walk under “Sin grupo”
- **AND** completing the squat leaves the walk next in the session

#### Scenario: Only one group is visible
- **WHEN** the visible exercise list contains only members of one named group or only unassigned exercises
- **THEN** Train shows those exercises in session order without a group heading

### Requirement: Partial completion preserves performed work
The app SHALL permanently close a session when the user finishes it, retain performed sets and ratings, mark the remaining work as unperformed and mark the cycle day complete. It SHALL retain incomplete workouts.

#### Scenario: Finish before completing all work
- **WHEN** the user finishes after two sets of a four-set exercise
- **THEN** the app retains both sets, allows a rating for the partial exercise and leaves no pending work for another session

#### Scenario: Last exercise
- **WHEN** the user finishes the last set of the last pending exercise and all other exercises are complete or skipped
- **THEN** the app shows the finished workout immediately without starting a final rest

### Requirement: Open session recovery
The app SHALL retain progress after an unexpected closure and allow the user to continue or finish the work already performed, even on another date. Locking the phone or leaving the app SHALL keep the session open.

#### Scenario: Recover the next day
- **WHEN** the user opens the app the next day with a pending session
- **THEN** the app offers to continue the session or finish the work already saved, and only finishing marks the cycle day complete

### Requirement: Supersets
The app SHALL support usual and temporary supersets, including exercises from different groups, with equal set counts and different repetitions or durations. Each round SHALL include one set of each member and rest at the end. The user SHALL be able to dissolve a superset during a workout and explicitly save a change as usual.

#### Scenario: Group exercises with incompatible set counts
- **WHEN** the user groups exercises with different set counts
- **THEN** the app requires a common set count before activating the superset

#### Scenario: Dissolve a superset during a session
- **WHEN** the user dissolves the superset
- **THEN** the app retains performed sets and makes each member’s remaining sets available without duplication

### Requirement: Cardio
The app SHALL represent cardio through instructions and a duration timer. The initial scope SHALL exclude recording distance, speed and resistance.

#### Scenario: Prescribed cardio
- **WHEN** the user starts a 15-minute cardio exercise
- **THEN** the app shows its instructions and a duration timer
