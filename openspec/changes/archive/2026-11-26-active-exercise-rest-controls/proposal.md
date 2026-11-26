# Active exercise rest controls

## Why

Rest is the moment to rate the exercise just completed and choose an available station. The active workout should keep both decisions beside the countdown and make the next action clear.

## What Changes

- Ask for optional one-tap effort feedback during rest after completing an exercise. OK acknowledges the question with no effort value.
- Identify the next set, next exercise or next superset member on the Up Next card.
- Let the user repeatedly postpone from that card during an inter-exercise rest. Cycle through pending exercises and intact supersets, then perform the selected block before returning to the remaining work in its original order.

## Capabilities

### New Capabilities

### Modified Capabilities

- `workout-sessions` gains contextual next-work headings and circular postponement.
- `exercise-progression` gains optional inline effort feedback tied to the completed exercise.

## Impact

Affects WorkoutSessionView, localized strings, TrainingKit session commands and open-session recovery. The training-list-improvements change covers the Train overview. This change covers the active workout and can be implemented independently.
