# Tasks

## 1. Private backup and restore

- [ ] 1.1 Test the new backup and restore flows in Settings using sample dates and states. Review with the user how they identify the latest backup and choose one to restore; refine the flow before connecting CloudKit.
- [ ] 1.2 Configure CloudKit capabilities and the private container once membership is available. Verify separate access with both test accounts.
- [ ] 1.3 Implement a consistent versioned snapshot, asset uploads, and a final manifest. Test network interruption and verify that an incomplete backup is never published.
- [ ] 1.4 Implement automatic retry and latest-backup status. Test a missing account, quota limits, offline use, and reconnection without blocking sessions.
- [ ] 1.5 Implement restoration to a temporary store and validated replacement. Test a corrupt backup, an older schema, and preservation of local data on failure.
- [ ] 1.6 Define and document retention and account switching. Verify isolation between users and that a valid backup is preserved during renewal.
