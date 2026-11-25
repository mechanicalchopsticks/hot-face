# Design

## Context

See proposal.md for motivation. The intended devices are an iPhone 15 Pro and iPhone 16. The app has a Live Activity extension, shared storage, and planned production CloudKit backup. Existing simulator and iPhone 15 Pro findings are documented in the foundation tasks and lock-screen guide.

## Goals / Non-Goals

**Goals:** Establish a renewable private installation and verify the integrated app on both target devices with preserved data and separate iCloud accounts.

**Non-Goals:** Public App Store distribution or a second account system.

## Decisions

### Ad Hoc signing with stable identity

Use Apple Developer membership, registered device identifiers, and matching app, extension, App Group, Health, and iCloud entitlements. Document profile expiration and renewal. Free signing expires too quickly for routine use; TestFlight build expiration makes it unsuitable as the primary long-term channel.

### Validate the distributed build

Test production CloudKit and account isolation in the signed build rather than inferring them from development settings. Update over a prior installed build containing test data, and verify migration and recovery.

### Record evidence by environment

Run the complete create/import, partial workout, recovery, progression, backup, and export journey in Spanish and English on both iPhones. Review every applicable spec scenario and the audio and lock-screen matrix, marking evidence as macOS, simulator, or physical iPhone and reporting remaining limitations.

## Risks / Trade-offs

- Expired signing profiles -> document renewal and keep recoverable backups.
- Production entitlement mismatch -> verify all capabilities in the distributed build.
- Upgrade schema incompatibility -> make a recoverable backup before migration and test with frozen older data.

## Migration Plan

Register both devices, set a stable identity, create the signed build, and verify private installation. Test production restore and update-over-installation before declaring the release ready.

## Open Questions

- Final icon artwork can be chosen before packaging the distribution build without changing the behavior or task breakdown.
