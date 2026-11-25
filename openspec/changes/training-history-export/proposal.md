# Proposal

## Why

Saved workouts need a usable history and a portable record of what the user actually did. This is a separate delivery from workout execution and progression.

## What Changes

- Add a History flow for complete and partial sessions, sets, loads, progress, and personal records.
- Record dated changes to usual prescriptions and support dated notes with undo and redo during editing.
- Export workouts and prescription changes as documented CSV files.

## Capabilities

### New Capabilities

- `training-records`: Review completed workouts, prescription changes, notes, progress, and CSV exports.

### Modified Capabilities

None.

## Impact

Builds on the local sessions, routine snapshots, gyms, and progression from `gym-training-mvp`. A redesigned History tab, repository queries, change records, and export formatting are required. Private backup belongs to `private-backup-restore`.
