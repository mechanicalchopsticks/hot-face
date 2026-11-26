## MODIFIED Requirements

### Requirement: Exercise groups in the Train list
Train lists for selecting, postponing or reordering exercises SHALL use the day editor’s group headings: one heading per visible group when at least two are present, counting unassigned exercises as one localized “Ungrouped” section. The list SHALL preserve session order within each group and SHALL leave the next exercise determined by the session sequence.

#### Scenario: Show groups while keeping the next exercise in session order
- **WHEN** the Spanish Train list opens with a squat, a walk and a lunge in session order, with the squat and lunge assigned to “Pierna” and the walk unassigned
- **THEN** the list shows the squat and lunge under “Pierna” and the walk under “Sin grupo”
- **AND** completing the squat leaves the walk next in the session

#### Scenario: Only one group is visible
- **WHEN** the visible exercise list contains only members of one named group or only unassigned exercises
- **THEN** Train shows those exercises in session order without a group heading

#### Scenario: Superset spans categories
- **WHEN** row and press form a superset in a session ordered row, squat, press
- **THEN** the list places a single labeled row/press block at the row position under the category of row, with each member displayed once
- **AND** dragging the block moves both members together in their relative order for this session

## ADDED Requirements

### Requirement: Open workout list and actions
Train SHALL show session exercises alongside Continue Workout and Finish Workout. Completed exercises SHALL initially show a checkmark. Users SHALL be able to hide and restore completed entries, swipe for applicable postpone and skip actions, and drag to reorder in edit mode.

#### Scenario: Return to an open workout
- **WHEN** the user hides completed exercises and then restores them
- **THEN** completed entries reappear checked and the session retains its progress and order

### Requirement: Superset round overview
During a superset the app SHALL identify the round, show every member in order and distinguish completed, current and upcoming exercises.

#### Scenario: Rest between rounds
- **WHEN** a round ends and the next round has yet to begin
- **THEN** the overview remains visible and identifies the next round's starting exercise

### Requirement: Discard an open workout
The app SHALL offer a confirmed discard from Train and during training. Discard SHALL remove the workout and its performed sets from recovery and history, end its timers and activities, and leave the day available to restart. Ratings, their effects on progression, and changes explicitly saved as usual SHALL persist.

#### Scenario: Cancel discard
- **WHEN** the user cancels the confirmation
- **THEN** the workout can continue with its existing progress

#### Scenario: Restart after discard
- **WHEN** the user confirms discard after logging a set and saving a prescription as usual
- **THEN** restarting the day uses the saved prescription with no completed sets from the discarded session

#### Scenario: Keep ratings after discard
- **WHEN** the user discards a workout with a rated exercise
- **THEN** the rating and its contribution to progression remain, including for workouts opened before this update
