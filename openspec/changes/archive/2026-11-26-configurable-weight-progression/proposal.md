# Proposal

## Why

The next available weight can be a much smaller increase than the 10% target, even when the gym has a closer match. Some users also prefer a slightly larger weight increase before adding repetitions.

## What Changes

- Add a global Conservative or Aggressive preference alongside repetition and rest settings. Default to Conservative for new and existing users.
- In both modes, choose the available increase closest to 10% from below, including exactly 10%.
- When that range is empty, Aggressive also considers increases through 15% before using the existing repetition bridge.

## Capabilities

### New Capabilities

### Modified Capabilities

- `exercise-progression` will govern the preference, direct weight increases and the transition to the repetition bridge.

## Impact

Affects the app's settings, preference persistence and TrainingKit's selection of weight increases at exercise start.
