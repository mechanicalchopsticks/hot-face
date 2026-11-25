# Design

## Context

See proposal.md for motivation. The app uses local storage as the operational source of truth. Two people use separate devices and Apple accounts. Backup is a recovery feature, not simultaneous editing across devices.

## Goals / Non-Goals

**Goals:** Create consistent private snapshots, publish only complete backups, and restore through validation without endangering current local data.

**Non-Goals:** Live CloudKit sync or a full-backup file export.

## Decisions

### Versioned snapshots in private CloudKit

Prepare a consistent local snapshot, upload its assets, then publish a versioned manifest only after all uploads succeed. The manifest identifies schema and integrity information. This avoids exposing incomplete backups as successful, unlike updating a single mutable cloud record in place.

### Local-first retry and status

Keep backup work separate from workout commands. Show the date of the last confirmed backup and any pending work. Retry after reconnection or account recovery without blocking an offline workout.

### Validate before replacement

Download and validate the selected backup, migrate it in a temporary store, then replace the live store only after validation. Retain a local pre-restore copy. This protects the current data from corrupt or older backups.

### Account isolation and retention

Use each person's private CloudKit database. Keep the latest valid backup and a small set of prior valid backups; document the exact count and frequency before release. Treat an Apple account change as a visible state change, never an implicit merge or restore.

## Risks / Trade-offs

- iCloud unavailable, quota exceeded, or account changed -> keep local training usable and show pending or failed status.
- Snapshot schema changes -> version manifests and test migration with frozen earlier data.
- Restore interrupted -> leave the live store untouched until the replacement is ready.

## Migration Plan

Prototype Settings states with sample dates first. Add CloudKit capability when developer membership is available. Test interruption, corrupt backups, older schemas, and two account identities before production validation in `private-distribution-validation`.
