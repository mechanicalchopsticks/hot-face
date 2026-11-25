# Proposal

## Why

The finished app must be installable and maintainable on both intended iPhones while preserving each user's data through updates. Simulator and development-build evidence alone cannot establish this.

## What Changes

- Prepare private Ad Hoc distribution with a stable app identity and registered devices.
- Validate production iCloud access, account isolation, upgrades, and recovery on distributed builds.
- Run the integrated workout, import, progression, backup, and export journeys on both devices and in both languages.

## Capabilities

### New Capabilities

- `private-distribution`: Install, update, and maintain the app privately on the intended devices.

### Modified Capabilities

None.

## Impact

Depends on the feature changes, Apple Developer membership, signing, production CloudKit configuration, and physical-device testing. This change records release evidence and outstanding limitations.
