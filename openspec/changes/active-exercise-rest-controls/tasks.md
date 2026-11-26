# Tasks

## 1. Session transitions and selection

- [x] 1.1 Expose the rest origin, transition kind and selected next set through OpenWorkout. Test repeated sets, exercise changes and superset member transitions through logged session commands.
- [x] 1.2 Add rest-scoped circular selection over eligible blocks. Test repeated wraparound, choosing C then resuming A/B/D, single-block behavior, supersets and explicit dissolution through SessionCommandTests.
- [x] 1.3 Connect selection to actual next-work execution. With an injected clock verify expiry, early rest completion, repeated command receipts and stale taps preserve the correct deadline and exercise. Reopen a disk store to verify recovery and cover changed encoded payloads with frozen pre-change fixtures.

## 2. Effort feedback

- [x] 2.1 Expose the completed exercise as the feedback target and support neutral acknowledgment alongside open-session ratings. Verify Hard and Easy apply once, OK leaves effort empty, and unanswered rests can expire. Reopen the session after OK to verify dismissal survives recovery.
- [x] 2.2 Add the localized inline question and three one-tap responses to WorkoutSessionView. Verify in the simulator that changing the preview keeps the feedback target and answering leaves the countdown running.

## 3. Upcoming work card

- [x] 3.1 Render localized headings, exercise names and set or round context. Verify the three distinct transitions in the simulator, including immediate progression to a superset member.
- [x] 3.2 Wire Postpone to the inter-exercise rest card. Verify repeated taps cycle in place, one remaining block offers no action, and ending the rest starts the displayed candidate when the user begins its work.
- [ ] 3.3 Format edited Swift, run repository Swift format lint and run `swift test --package-path TrainingKit` with Xcode selected. Run the affected simulator UI tests and report the environments and results.
