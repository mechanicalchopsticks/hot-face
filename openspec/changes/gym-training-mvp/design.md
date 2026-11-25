# Design

## Context

See proposal.md for motivation. The foundation supports one private, offline workout store per device. The intended devices are iPhone 15 Pro and iPhone 16. Later changes own detailed History and CSV, private backup, photo import, and release distribution.

## Goals / Non-Goals

**Goals:** Keep deterministic workout rules separate from iOS services, persist every action before reporting success, preserve past sessions when routines change, and make progression suggestions optional and reproducible.

**Non-Goals:** A server dependency for training, shared accounts, automatic translation of user text, Markdown import, or AI-generated prescriptions.

## Decisions

### Native app and module boundaries

Use Swift and SwiftUI. TrainingKit separates domain rules, repositories, adapters, and interface helpers. The app presents Train, Routines, History, and Settings, with a session screen focused on the current set. Native iOS services are required for timers, audio, Live Activities, and Lock Screen controls; a cross-platform shell would add complexity for an iPhone-only product.

### Local versioned persistence

Use a versioned local store with routine, gym, equipment, cycle, session, actual-set, and progression entities. A session takes a prescription snapshot on start so later routine edits or archiving cannot rewrite history. Persist commands with stable identifiers and idempotent handling so duplicate taps or extension actions cannot duplicate a set. Coordinate app and extension writes through shared storage. Reopen frozen prior-version fixtures when changing stored data or encoded payloads.

The local store is the operational source of truth. Cloud backup is specified separately; this change does not enable automatic whole-store sync. A partial finish permanently closes the session, retains performed work, and marks remaining work unperformed. An open session retains progress for later recovery, including on a different date. Switching gyms or routines with an open session requires the user to continue or finish it first.

### Gym inventories and load representation

Each gym has editable shared inventories of individual dumbbells, fixed bars, and plate sizes with a unit on every entry. New gyms receive initial values once; later edits survive reopening. Exercises select from their gym's available loads, while preserving the chosen physical load, representation, implement count, and estimated or confirmed state. A missing load differs from zero.

For selectorized machines, offer 5 through 150 kg in 5 kg increments. For plate-loaded equipment, calculate reachable symmetric added loads using repeatable plate sizes and cap each side at the lower of 250 lb and the equipment limit. The equipment's own weight is included only in a display that calls for it; limits and progression percentages use added weight. Migrate earlier per-equipment catalogs into shared gym inventories without changing historical snapshots.

### Initial load from local history

For a new, copied, or imported routine, find the latest actual load by gym identity and exercise name across archived routines and partially finished sessions. Ignore skipped work and missing loads; retain zero and corrections. Show the prior date, prescription, station, instructions, load, and unit for context without repeating the gym name. Only explicit confirmation writes a suggested initial load. A copied load remains unless the user replaces it.

### Progression rules

Store an effort balance from -2 to +2. Ratings are optional; opposite ratings cancel, and a missing rating does not change the balance. A usual change resets the balance; a temporary session adjustment does not. The engine receives the usual prescription, balance, reachable loads, and any repetition bridge, and returns a structured, localizable suggestion or a manual-adjustment invitation. It never applies changes automatically.

At +2, a next load no more than 10% higher preserves repetitions. A larger jump first uses the next repetition step and records the prior count as a bridge; after another +2, the higher load returns to that count. At -2, prefer the next lower load, then a lower repetition step. Do not invent numeric suggestions when load or inventory is missing. Timed or combined exercises remain manual. Task 6.6 requires user review of the proposed rule that a custom edit inconsistent with a pending bridge invalidates it.

### Timers, audio, and Lock Screen actions

Persist timing phase, deadline, paused remainder, side, round, and next transition. Derive remaining time from an injectable clock, not an in-memory counter. Evaluate the same transition rules from the app and Lock Screen actions. Use ActivityKit and App Intents for visible controls, AlarmKit and audio services where feasible, and a short ducking cue rather than continuous silent audio. A visible Live Activity alone does not guarantee a background callback. Preserve the device observations and remaining limits in tasks.md and the Workout Lock Screen guide.

### Incremental tab flows and localization

After the first routine, test an interactive Train flow with sample data on an unlocked iPhone, then its Lock Screen counterpart, before connecting storage and services. Apply the same prototype, user walkthrough, and integration sequence to later tab features in their own changes. Keep sample fixtures separate from user data.

Use String Catalogs in the app and extensions. Store language-neutral codes and parameters for suggestion reasons; format numbers and dates for the device locale without converting the chosen kg/lb unit or translating user-entered names and notes. Test both languages, long text, Dynamic Type, and accessibility.

## Risks / Trade-offs

- Lock Screen execution and audio depend on iOS state and permissions -> retain physical-device evidence and report limitations explicitly.
- Concurrent app and extension actions can race -> coordinate writes and verify idempotent recovery.
- Schema changes can affect old workouts -> retain frozen fixtures and validate migrations before replacing data.
- Progression can suggest an unreachable load -> use the same gym load options as the editor.

## Migration Plan

1. Complete the remaining progression tasks and verify stored balances and suggestions against existing workout data.
2. Reopen prior-version fixtures after any schema change; keep old fixture bytes unchanged.
3. Archive this foundation only when its scoped tasks and capability scenarios are complete. Continue the other functional areas in their separate changes.
