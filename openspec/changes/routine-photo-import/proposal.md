# Proposal

## Why

Entering a routine from a two-sided paper sheet is slow and error-prone. The app can prepare an editable draft while leaving uncertain interpretations to the user.

## What Changes

- Extract a combined routine draft from two photos, including handwriting, colors, numbering, and prescriptions.
- Let the user review and correct each day against the source images before saving.
- Apply a gym-specific, confirmable convention for abdominal exercises without an assigned day.

## Capabilities

### New Capabilities

- `routine-photo-import`: Extract, review, and save routine drafts from two photos.

### Modified Capabilities

None.

## Impact

Builds on the manual routine editor and gym catalog from `gym-training-mvp`. May require a small authenticated extraction service, provider evaluation, image handling, and an import review flow. Offline training remains independent of extraction.
