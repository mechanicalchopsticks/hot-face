# Design

## Context

See proposal.md for motivation. The foundation persists versioned routine snapshots, actual sets, gym and equipment context, and complete or partial sessions. Progression adds ratings and confirmed changes to usual prescriptions.

## Goals / Non-Goals

**Goals:** Query immutable workout facts, present them in History, record subsequent usual-setting changes, and export stable CSV data.

**Non-Goals:** Cloud backup or visual import.

## Decisions

### Prototype the History flow before wiring queries

Use fixtures for a complete and a partial session, including two completed sets prescribed to failure with only one count entered. Review the interactive flow with the user, then connect the agreed screens to the repository. This follows the tab workflow established in the foundation and prevents persistence details from defining the UI.

### Keep performed facts separate from current prescriptions

Read actual sets from saved session snapshots. Store dated usual-setting changes with previous and final values; a later routine edit must not change a past workout. A generic event log over all UI edits would blur temporary corrections with usual changes.

### Use stable CSV fields

Export explicit units, unambiguous dates, stable identifiers, and links between rows. Quote special characters and multiline notes. Keep zero distinct from missing values and do not localize column identifiers, so the same export remains interpretable from either interface language.

## Risks / Trade-offs

- Old sessions lack some newer fields -> preserve their recorded meaning and show missing values explicitly.
- A change may be recorded twice during retry -> persist changes with the same idempotent command boundary as the usual-setting update.
- CSV can expose personal text -> export only on explicit user action.

## Migration Plan

Add versioned change and note records while retaining existing sessions. Reopen a frozen older store to verify history. Validate the CSV contract using complete and partial sessions before release.
