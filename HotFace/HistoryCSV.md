# Training history CSV

In **History → Export CSV** (**Historial → Exportar CSV**), choose a folder for the five files. Each export reads one snapshot of the local history, including archived routines. The interface language controls the button labels. The files use the same names and formats in both languages.

| File | One row represents | Join |
| --- | --- | --- |
| `sessions.csv` | A finished session, complete or partial | `session_id` |
| `exercises.csv` | An exercise in that session’s saved prescription | `session_id` + `exercise_id` |
| `sets.csv` | A numbered set, including omitted work | `session_id` + `exercise_id` + `set_number` |
| `changes.csv` | One side of a dated change to a usual prescription | Group stages by `change_id` |
| `notes.csv` | A saved note | `note_id`, with optional session and exercise references |

## File conventions

- Read as UTF-8 CSV with a header, comma delimiters, and CRLF record endings. Text containing commas, line breaks, or double quotes is quoted. A double quote inside that field is doubled. Use a CSV reader that supports multiline fields.
- Identifiers are UUIDs. Timestamps are ISO 8601 in UTC with fractional seconds. Decimal values use a period. Booleans are `true` and `false`. Names, instructions, and notes retain their original text.
- An empty numeric field means the value was unavailable or inapplicable. A recorded zero is written as `0`. A file with no matching records contains its header.
- `segments` lists the segments of one set in execution order, separated by `|`. Examples are `reps:8`, `seconds:30`, and `reps:7|reps:7|reps:7`. In a prescription, `failure` is the target. In a performed set it means the set was performed to failure with an unspecified count. A counted failure set can have `failure` in the exercise row and `reps:12` in the set row.

## Sessions

| Columns | Meaning |
| --- | --- |
| `session_id`, `started_at`, `finished_at` | Session identity and recorded start and finish |
| `duration_seconds` | Elapsed seconds including rests. Empty for an invalid interval |
| `status` | `complete` or `partial`, as recorded at finish |
| `gym_id`, `gym_name`, `routine_id`, `routine_name`, `routine_revision`, `day_id`, `day_name` | Gym, routine revision, and training day captured in the session |

## Exercises and prescription changes

These files share the following prescription columns.

| Columns | Meaning |
| --- | --- |
| `exercise_id`, `exercise_name`, `equipment_id`, `station` | Exercise identity, recorded name, assigned equipment, and exercise-specific station |
| `exercise_group`, `variant`, `band_color`, `instructions` | Optional group, variation, resistance band color identifier, and exercise instructions |
| `set_count`, `segments`, `per_side` | Prescribed set count, segment sequence, and whether to perform it on each side. An older change can leave the count empty when the exercise inherited a routine default |
| `load_status` | `undefined`, `estimated`, or `confirmed` |
| `load_amount`, `load_unit`, `load_representation`, `implement_count` | Prescribed load, its recorded unit (`kg` or `lb`), how the weight was expressed, and the stored implement count |

Load representations are `perImplement` (each implement), `combined` (all implements together), `perSide` (weight added on each side), `totalAdded` (all added weight), and `includingEquipment` (loaded weight including the implement). Preserve the representation, implement count, gym, and equipment when comparing loads.

**Exercises** also include `session_id`, the one-based exercise `position`, `equipment_name`, `equipment_station`, the exercise’s `skipped` flag, and optional `effort` (`easy` or `hard`). An exercise skipped after some sets can still have performed rows.

**Changes** also include `change_id`, `routine_id`, `changed_at`, `origin`, and `stage`. Origins include `routine`, `workout`, `replacement`, and `suggestion.<reason>`. An explicit replacement pairs the old and new exercise identifiers. The routine editor records an added exercise as a single `final` row and a removed exercise as a single `previous` row, each with its own change identifier. An accepted suggestion has both stages even when the user confirms the current values. Equivalent display conversions produce no entry. The final row of an edited suggestion contains the values the user saved.

## Sets

| Columns | Meaning |
| --- | --- |
| `session_id`, `exercise_id`, `set_number` | Parent exercise in its session and one-based set number |
| `set_id`, `performed_at` | Identity and timestamp of the actual set. Both are empty for omitted work |
| `status` | `completed`, `partial` (a recorded partial set), `skipped` (explicitly skipped), or `unperformed` (remaining at finish) |
| `segments`, `second_side_segments`, `per_side` | Actual sequence and per-side flag. A distinct second-side sequence is included when recorded |
| `load_amount`, `load_unit`, `load_representation`, `implement_count` | Actual load in the same format as the prescription. Omitted work has empty performance fields |

## Notes

`note_id` identifies the note. `created_at` preserves its original date after editing. `text` contains the latest saved text, including line breaks. `session_id` and `exercise_id` identify the linked records when present. General notes can have both references empty.

## Reading a partial session

In the bilingual verification sample, the session lasts 60 seconds. The first three set rows are completed. Their loads are 0 lb, empty, and 12.5 kg. The middle row has `failure` in `segments`, so it counts toward completed sets. The last two rows are unperformed and skipped. Joining by `session_id` and `exercise_id` recovers the day, exercise names, and targets for all five rows.

The English and Spanish interfaces produced byte-identical copies of all five files on the iPhone simulator, including the paired prescription change and a note containing commas, quotes, and a line break.
