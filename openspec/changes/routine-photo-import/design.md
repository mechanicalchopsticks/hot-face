# Design

## Context

See proposal.md for motivation. The foundation already has a manual routine editor and gym-specific load selection. The two sample sheets contain printed and handwritten text, colors, crossed-out stations, and distinct legends.

## Goals / Non-Goals

**Goals:** Build a reviewable draft from both selected images and save only user-reviewed values through the routine editor.

**Non-Goals:** Automatic load invention, a server dependency for training, or direct edits to the active routine during extraction.

## Decisions

### Separate extraction from routine persistence

An adapter converts the two images to structured candidates with source references and uncertainty flags. The draft does not change a routine until review and save. This keeps extraction failures reversible and lets users correct order, day, station, and prescription.

### Evaluate a vision provider before paid processing

Compare provider cost, image handling, retention, and accuracy on authorized local samples, then review the provider and cost choice with the user before enabling paid processing. A text-only OCR approach cannot reliably interpret color legends and handwritten markings. Keep provider credentials in a small authenticated service, not in the iPhone app, and exclude image contents from logs.

### Use gym conventions as tentative rules

The abdominal-to-Day-1 convention applies only to the configured gym and is marked for confirmation. Explicit day assignments take priority. Ambiguous general instructions remain visible for user placement.

### Integrate through the existing editor

After review, populate the manual editor and let the user define supersets. Missing loads remain undefined unless the user enters one or confirms a gym-history suggestion. Training remains fully offline after the routine is saved.

## Risks / Trade-offs

- Extraction misreads handwriting or colors -> show source images and uncertain fields in mandatory review.
- Provider outage or timeout -> preserve the draft and allow retry.
- Private samples leak into public fixtures -> use synthetic contract tests and keep authorized samples local.

## Migration Plan

Prototype review with a preloaded draft. Define and test the extraction contract with synthetic samples, evaluate the provider, then integrate the service and editor. Verify import through offline training before release.
