# Active exercise rest controls

## Context

WorkoutSessionView labels upcoming work during rest as “Up next.” OpenWorkout resolves the next set and superset round. SessionCommands already supports open-session effort ratings. Its move-to-back command changes the prescription order on each call, which would leave D ahead of A after browsing to C.

## Goals / Non-Goals

Keep a single authoritative next set across the active screen, timer expiry, recovery and existing workout actions. The Train overview and general list reordering belong to training-list-improvements.

## Decisions

- Derive the transition from the exercise and set that initiated the rest and the resolved upcoming work. Identify an intra-superset member transition before applying the generic different-exercise label. Keep set and round counters from the existing scheduler.
- At the start of inter-exercise rest, retain the ordered eligible block IDs and the current selection. Group by superset identity at the earliest pending member. Advance one index modulo the block count per deliberate tap. Resolve the effective order as selected block followed by the other blocks in baseline order. Keep the selection through timer expiry or early rest completion so the next action actually performs the card's choice. Preserve existing round scheduling within the selected block.
- Use a dedicated session command for cycling. Bind it to the expected rest and candidate so retries, stale taps and timer expiry cannot advance an unrelated rest. Reconcile removed, completed, skipped or dissolved blocks against current pending work. Preserve the usual routine.
- Bind the rating prompt to the completed exercise and rest identity. Route Hard and Easy through the existing open-session rating path. Store OK as an acknowledgment scoped to this prompt, separate from effort. Read the acknowledgment and existing rating on recovery. Keep existing post-workout rating behavior and avoid applying the same rating twice.
- Localize the three headings and the named question. In Spanish use “Siguiente serie”, “Siguiente ejercicio”, “Siguiente ejercicio de la superserie” and the buttons “Difícil”, “OK”, “Fácil”. Present actions inline, with no modal or extra confirmation.

## Risks / Trade-offs

Rest actions and rating commands can race with timer reconciliation. Validate the rest identity transactionally and reuse existing command receipts. Opening a previous session may yield no rest-selection metadata. Derive its initial candidate from the stored session's next work.

## Migration Plan

Keep any new encoded session fields optional with defaults for older payloads. Verify a frozen pre-change fixture and reopen a disk store after selecting a candidate and acknowledging a prompt. Do not rewrite historical ratings or routine order.
