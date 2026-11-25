## Purpose

Keep HotFace privately installable and maintainable on the two intended iPhones while preserving each person's training data through updates.

## ADDED Requirements

### Requirement: Private device installation
The app SHALL be installable on the two registered iPhones through private Ad Hoc distribution with a stable app identity and documented renewal steps.

#### Scenario: Install on a registered iPhone
- **WHEN** a signed build is installed on either registered device
- **THEN** HotFace launches with its required capabilities and can be renewed before its profile expires

### Requirement: Data-preserving update
An update SHALL preserve compatible local training data and make a recovery path available before an incompatible schema change.

#### Scenario: Update an existing installation
- **WHEN** a newer build replaces an installation containing test routines and history
- **THEN** the app can open or migrate that data without silently losing the records

### Requirement: Production account isolation
The distributed build SHALL use each user's private iCloud data without exposing one person's backup to the other.

#### Scenario: Restore on two accounts
- **WHEN** each person restores a test backup on their own distributed build
- **THEN** each receives only their own routines, settings, and history
