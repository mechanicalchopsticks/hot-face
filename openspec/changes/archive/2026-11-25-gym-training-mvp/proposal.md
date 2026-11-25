# Proposal

## Why

Replace manual Markdown logging of routines and loads with a private iPhone app that guides offline training, preserves what was actually performed, and suggests progression under the user's control. Two people use separate devices and Apple accounts with independent local data.

## What Changes

- Create, edit, copy, archive, and cycle manual routines; suggest an initial exercise load from that gym's recorded history.
- Manage gyms, equipment, available loads, and exercise-specific load representations.
- Guide recoverable workouts with set corrections, temporary adjustments, skips, additional exercises, and supersets. Preserve performed work when a session ends early.
- Provide timers, audible cues, and Lock Screen actions with documented physical-device limits.
- Add optional effort ratings and editable progression suggestions based on a capped balance and explicit load and repetition rules.
- Localize the app and extension in English and Spanish according to device settings.
- Exclude Markdown import, social features, Android, cardio distance/speed/resistance logging, and automatic AI prescription.

History exploration and CSV, private backup and restore, photo import, and private distribution are planned in separate OpenSpec changes. This change retains the completed foundation work and unfinished progression tasks.

## Capabilities

### New Capabilities

- `routine-cycles`: Manual routines, days, cycles, archiving, and copying.
- `gym-equipment`: Gyms, equipment, inventories, loads, and exercise load representation.
- `workout-sessions`: Offline execution, recovery, adjustments, actual sets, and supersets.
- `workout-timers`: Exercise and rest timers, cues, and Lock Screen controls.
- `exercise-progression`: Effort balances and confirmable suggestions.
- `app-localization`: English and Spanish interface and regional formatting without changing user data.

### Modified Capabilities

None; this project has no archived capability specs yet.

## Impact

Native Swift and SwiftUI iPhone app with a local versioned store, TrainingKit modules, and Apple adapters for Lock Screen behavior. The target devices are iPhone 15 Pro and iPhone 16. The current change remains in progress until tasks 6.1–6.7 are completed. Subsequent changes consume its local data and UI foundations.
