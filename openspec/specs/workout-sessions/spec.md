# workout-sessions Specification

## Purpose

Guide workouts offline and save progress while distinguishing the usual prescription from what the user actually performed.

## Requirements

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

### Requirement: Optional repetition count for sets performed to failure
For a set prescribed to failure, one tap on Complete Set SHALL mark the set complete and start the applicable rest without requiring a repetition count. During rest, the user SHALL be able to enter the actual repetitions for that set. The workout history SHALL retain each completed set, with its count left unspecified when the user omits it.

#### Scenario: Record repetitions for only one of two completed sets
- **WHEN** the user completes two sets prescribed to failure, enters 12 repetitions during the first rest and leaves the second count blank
- **THEN** the history shows both sets as complete, with 12 repetitions for the first and no recorded count for the second
- **AND** the exercise remains prescribed to failure

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

### Requirement: An active HealthKit session during training
With workout permission, HotFace SHALL start a HealthKit workout session when the user starts or continues training. It SHALL keep that session active across sets, pauses, rests, exercise changes and normal iPhone locking. Closing the workout screen or finishing the workout SHALL end the HealthKit session and discard its Health data. When Health is unavailable or permission is denied, the local workout SHALL remain usable.

#### Scenario: Continue through rest without reopening HotFace
- **WHEN** a timed set and its rest expire while the iPhone is locked with Live Activities enabled
- **THEN** the card shows the next set ready for the user and the same HealthKit session continues into that set

#### Scenario: Leave a workout for later
- **WHEN** the user closes a workout and later chooses **Continue workout**
- **THEN** HealthKit ends when the user leaves and starts again when they continue, and HotFace retains the saved progress

### Requirement: Show the latest workout cue
HotFace SHALL keep the most recently delivered workout cue visible and remove older delivered workout cues when it can run, including when it resumes after suspension.

#### Scenario: A rest cue follows a hold cue
- **WHEN** iOS delivers the hold and end-of-rest notifications in sequence while the iPhone is locked and workout sounds are enabled
- **THEN** HotFace keeps the end-of-rest notification and removes the earlier hold notification
- **AND** the user hears both cues
- **AND** future cue sounds remain scheduled and unrelated notifications are preserved

### Requirement: Supersets
The app SHALL support usual and temporary supersets, including exercises from different groups, with equal prescribed set counts and different repetitions or durations. Starting when the superset is formed, each round SHALL include the next pending set of each member that still has work, in day order. The app SHALL rest between rounds, including when only one member remains. The user SHALL be able to dissolve a superset during a workout and explicitly save a change as usual.

#### Scenario: Group exercises with incompatible set counts
- **WHEN** the user groups exercises with different set counts
- **THEN** the app requires a common set count before activating the superset

#### Scenario: Form a superset after starting an exercise
- **WHEN** the user groups row and press in that order for three sets each after completing row sets 1 and 2
- **THEN** round 1 contains row set 3 followed immediately by press set 1, round 2 contains press set 2, and round 3 contains press set 3
- **AND** the app starts the configured between-round rest after press set 1 and again after press set 2
- **AND** if the user reopens the workout immediately after logging row set 3, the app shows press set 1 in round 1 of 3, ready to start

#### Scenario: Dissolve a superset during a session
- **WHEN** the user dissolves the superset
- **THEN** the app retains performed sets and makes each member’s remaining sets available without duplication

### Requirement: Cardio
The app SHALL represent cardio through instructions and a duration timer. The initial scope SHALL exclude recording distance, speed and resistance.

#### Scenario: Prescribed cardio
- **WHEN** the user starts a 15-minute cardio exercise
- **THEN** the app shows its instructions and a duration timer
