# workout-timers Specification

## Purpose

Guide exercise and rest periods with distinct cues and keep timing when the user locks the iPhone or switches apps.

## Requirements

### Requirement: Exercise timer
The app SHALL visually distinguish exercise from rest and allow the user to start, pause, resume and end a timed set early. Starting or resuming SHALL include three seconds of preparation. The app SHALL support configurable pauses between holds and configurable automatic restart.

#### Scenario: Resume a set
- **WHEN** the user resumes a paused exercise
- **THEN** the app gives the three-second preparation cue and continues the timer from the remaining time

#### Scenario: End a set early
- **WHEN** the user ends a timed set early
- **THEN** the app records the duration performed and proceeds to the corresponding rest or transition

### Requirement: Configurable rests
The app SHALL time rests, initially using 1:45 between sets and 2:15 between exercises. The user SHALL be able to configure rests for a routine, an exercise or a superset. The app SHALL allow the user to apply −15 s, apply +15 s or end the current rest. These actions SHALL affect only that rest.

#### Scenario: Heavy exercise
- **WHEN** the user sets rests of 2:15 between sets and 3:00 between exercises for one exercise
- **THEN** its rests use those durations and the general settings stay the same

#### Scenario: Immediate adjustment
- **WHEN** the user taps +15 s during a rest
- **THEN** the app adds 15 seconds to the remaining time and preserves the duration of future rests

### Requirement: End of rest
When a rest expires or the user ends it, the app SHALL stop the rest timer and leave the next set or exercise ready for the user to start. When a rest expires, the app SHALL play an audible cue.

#### Scenario: Return after a rest
- **WHEN** the rest expires while the user is outside the app and the user returns
- **THEN** the next set or exercise is waiting to start, without restarting the rest or automatically starting the exercise

### Requirement: Timer continuity and Lock Screen actions
Timers SHALL continue when the iPhone is locked or the user switches apps. From the Lock Screen, the user SHALL be able to complete a set and start its rest, and to start, pause and resume timed exercises.

#### Scenario: Timed set with the iPhone locked
- **WHEN** a regular timed set ends with the iPhone locked
- **THEN** the cue sounds and the corresponding rest begins without requiring the user to open the app

### Requirement: Distinct audio cues
The app SHALL provide distinct visual and audible cues for timer events, including the last hold and the last set. Cues SHALL be audible through headphones and briefly lower the volume of any music playing.

#### Scenario: Last set with headphones
- **WHEN** the last timed set ends while music is playing through headphones
- **THEN** the app plays the distinct cue through the active audio output, briefly lowers the music volume and restores it

### Requirement: Transitions between sides and superset exercises
For timed exercises performed per side, the app SHALL time each side separately and wait for the user to start the second side after the cue for the first. In supersets, the app SHALL wait for the user to start the next exercise in the round and rest only at the end of the round.

#### Scenario: First side
- **WHEN** the timer for the first side ends
- **THEN** the app plays a cue and waits for the second side to start without starting a rest between sets

#### Scenario: Intermediate exercise in a superset
- **WHEN** a timed exercise ends and another exercise remains in the round
- **THEN** the app plays a cue and leaves the next exercise ready for the user to start without starting a round rest
