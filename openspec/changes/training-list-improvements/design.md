# Design

## Context

Train currently offers resume and finish for an open workout. The saved session prescription and its progress determine exercise order and completion. The day editor also uses category sections, and supersets can span categories.

## Goals and non-goals

Keep workout presentation consistent across Train and the active workout. Preserve existing routine prescriptions, saved sessions and command payload compatibility.

## Decisions

- Derive list blocks from session order before applying category sections or visibility filters. Anchor each superset to its earliest member's category, even when a filter hides that member. Translate drag operations into stable exercise IDs so hidden exercises retain their relative order.
- Derive round status from session progress and the active phase. A separate UI counter would drift after recovery or a Lock Screen action.
- Place discard in the repository that owns session writes. Resolve the specific open session and remove its dependent progress in one coordinated write. Perform activity cleanup after the successful write. A stale action must not affect a later workout.
- Use shared duration presentation in TrainingInterface. Convert picker selections to the existing duration representation at the editing boundary. Opening an older prescription must not silently change its stored values.
- Keep text drafts local to the editor. Validate and normalize at save. Initialize the repetition count when creating an exercise so reopening a saved exercise preserves its prescription.

## Risks and mitigations

- Filtering or grouping may change row indices. Verify reorder with interleaved members and completed rows.
- Discard can race with activity actions. Reopen the disk store and exercise a late command against the discarded session.
- Duration output appears in multiple targets. Verify both the app and the Live Activity across a minute boundary.
