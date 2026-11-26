# Training List Improvements

## Why

Returning to Train with an open workout should show what is done, what comes next and which exercises belong together. A workout started by mistake also needs a way to discard its progress and leave the day available to train again.

## What Changes

- Show the session exercise list alongside Continue Workout and Finish Workout on Train. Reveal applicable exercise actions on swipe, including postponing and skipping. In edit mode, allow drag reordering for the current session.
- Keep completed exercises visible by default with a checkmark. Offer a reversible Hide Completed filter.
- Show each superset as one labeled block at the position of its earliest member in session order. List its members once in their relative order and move the whole block when reordering. For example, grouping row and press in a sequence of row, squat and press places the row/press block before squat.
- During a superset, show the round, list all members in order, highlight the current exercise and identify completed and upcoming work in the round. Keep the list visible during the rest between rounds and identify which exercise starts the next round.
- Offer Discard Workout during training and when returning to an open session. Ask for confirmation. Discarding removes the session and its progress from pending workouts, history and progression, and leaves the cycle day available to restart. Preserve changes explicitly saved as usual.
- Use minute and second selectors wherever durations are configured, including session adjustments. Cap configured rests at 10:00 and other configured durations at 60:00. Display durations throughout the interface as minutes and two-digit seconds, including countdowns (for example, 1:15 for 75 seconds).
- Preserve text exactly while the user edits. At save time, trim leading and trailing whitespace and newlines, preserve internal spacing and validate required fields against the trimmed value.
- Start each newly added repetition-based exercise at an editable 10 repetitions.

## Capabilities

### New Capabilities

- `text-entry` covers draft editing, trimming on save and required text validation across forms.

### Modified Capabilities

- `workout-sessions` covers the open workout list, exercise actions and order, superset presentation and discarding session progress.
- `workout-timers` covers duration selectors, configuration limits and duration display.
- `routine-cycles` covers the initial repetition prescription for newly added exercises.

## Impact

The change affects the Train tab, workout and routine editors, other text-entry forms, and duration displays in the app and its Live Activity. Session discard also affects local workout recovery, history, progression, and cleanup of active timers and workout activities.
