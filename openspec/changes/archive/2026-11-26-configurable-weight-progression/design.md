# Design

## Context

TrainingDomain computes advice from the usual prescription and the gym's weighted inventory. TrainingRepositories uses the same evaluator to generate an offer and to recheck it when accepted. The app presents that offer in WorkoutSessionView. GymSettingsView is the app-wide Settings entry point, while ExerciseEditor owns the existing “Sets and rest” section.

## Goals / Non-Goals

Keep a single mode across gyms and routines. Limit the algorithm change to direct increases for positive usual loads. Exercise prescriptions, effort balances and accepted bridges retain their existing meanings.

## Decisions

1. Define a typed progression mode in TrainingDomain. Keep the evaluator pure by passing the mode explicitly, with Conservative as the default for existing domain and repository callers. Forward it through offer, convenience and acceptance APIs to the shared evaluation in pendingAdvice. WorkoutSessionView reads the current preference when requesting and confirming an offer. If recomputation yields different advice, use the existing suggestionChanged path.
2. Store the selection under one stable app preference key with a Conservative fallback for absent or unrecognized values. A per-exercise field would duplicate a global choice and require rewriting existing records. Expose the same bound picker in Settings, including when the gym catalog is empty, and alongside “Sets and rest” in ExerciseEditor. Label the editor control as applying to all exercises. Save a selection immediately, independently of saving or cancelling exercise edits.
3. Rank candidates using the existing normalized added-weight values, including per-side handling and the inventory match for rounded display values. For a positive baseline and no pending bridge, take the heaviest increase at or below 110% of the baseline. Only when that set is empty may Aggressive take the lightest increase above 110% and at or below 115%. Use inclusive cross-multiplied comparisons in the existing numeric representation. Selecting the smallest heavier load first would miss a better match below the target.
4. Keep the smallest heavier load available for bridge completion, zero added weight and the existing 15-repetition fallback. Evaluate pending bridges before direct increases in either mode. When neither range qualifies, retain the current repetition-step, availability and manual-adjustment rules. Decreases continue to use the nearest lower load.

## Risks / Trade-offs

- An allowed jump above 10% could displace a smaller eligible increase. Cover both bands in the same inventory test, including mixed display units.
- A settings change while an offer is visible could make it stale. Re-evaluate at acceptance and verify rejection leaves the prescription and balance intact.
- Two picker locations could suggest an exercise-specific override. Bind them to one preference and verify both reflect the same value after relaunch.

## Migration Plan

Read a missing preference as Conservative on first install and upgrade. Existing stored workout records and bridge data need no conversion. A rollback can ignore the preference key and read the same records.
