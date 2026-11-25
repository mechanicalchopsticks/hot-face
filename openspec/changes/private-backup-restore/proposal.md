# Proposal

## Why

Local workout data must remain recoverable without making network access a condition for training. Each person uses a separate Apple account and needs an independent private backup.

## What Changes

- Add automatic, versioned backups in the account's private iCloud storage.
- Show backup status and restore from a validated backup without losing local data on failure.
- Handle offline use, retries, account changes, and retention.

## Capabilities

### New Capabilities

- `private-backup`: Independent private backups, status, and safe restoration.

### Modified Capabilities

None.

## Impact

Builds on the local versioned store from `gym-training-mvp` and covers the data added by later feature changes. Requires CloudKit capabilities, backup adapters, temporary-store validation, and account-specific Settings UI. Production validation belongs to `private-distribution-validation`.
