## Purpose

Keep each person's local training data recoverable through independent private backups without making a network connection necessary to train.

## ADDED Requirements

### Requirement: Independent private backup
The app SHALL back up routines, configuration, sessions, and history to the current user's private iCloud account when available. Accounts SHALL remain isolated.

#### Scenario: Two Apple accounts
- **WHEN** two people use separate Apple accounts on their own iPhones
- **THEN** each can access only their own backups for restore

### Requirement: Offline continuity and retry
The app SHALL keep training available while offline or while backup is pending and SHALL retry a pending backup when service becomes available.

#### Scenario: Reconnect after offline workouts
- **WHEN** workouts were saved locally without a connection and connectivity returns
- **THEN** the app can back them up without requiring the workouts to be entered again

### Requirement: Accurate backup status
The app SHALL show the last confirmed backup and pending or failed work without treating an incomplete upload as a successful backup.

#### Scenario: Upload interrupted
- **WHEN** the connection fails before a backup is complete
- **THEN** the app does not present that backup as restorable or successful

### Requirement: Safe restoration
The app SHALL validate a selected backup before replacing local data and SHALL preserve the existing local data if download, validation, or migration fails.

#### Scenario: Corrupt backup
- **WHEN** a user tries to restore a corrupt backup
- **THEN** the app reports failure and leaves the current local data available

### Requirement: Backup retention and account changes
The app SHALL retain at least one valid prior backup during renewal and SHALL make the active account and available backups clear before restoration.

#### Scenario: Account changes
- **WHEN** the iPhone switches to another Apple account
- **THEN** the app does not silently restore or merge the former account's data into the new account
