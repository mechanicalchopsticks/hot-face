# Tasks

## 1. Domain evaluation

- [x] 1.1 Add a typed mode to ProgressionAdvice.evaluate and WeightSuggestion.increase with a Conservative default. Implement the two candidate ranges. In ProgressionAdviceTests, use unordered inventories to cover multiple choices in each band, precedence across bands, exact 10% and 15%, and an increase just above 15%.
- [x] 1.2 Exercise both modes with normalized per-side and converted loads. Verify pending bridges complete after a mode switch and existing cases for zero load, 15 repetitions, no heavier load, decreases and manual adjustments still pass.

## 2. Repository integration

- [x] 2.1 Forward the mode through routine and session offers, acceptance and convenience APIs to pendingAdvice. Verify that accepting an Aggressive direct increase updates the usual prescription and session, records the change and resets the balance.
- [x] 2.2 Use SessionProgressionTests with an injected clock to show that changing the mode between offer and acceptance rejects a now-stale suggestion without mutating the prescription or balance. Verify that a bridge accepted in Conservative can complete in Aggressive.

## 3. App preference and controls

- [x] 3.1 Persist one mode preference and pass its current value from WorkoutSessionView on offer and confirmation. Verify missing and unknown values resolve to Conservative and a saved Aggressive choice survives relaunch.
- [x] 3.2 Bind the Settings picker and the control beside “Sets and rest” to the same preference. Localize the labels in English and Spanish. Verify Settings works with an empty gym catalog and that changing either control updates the other even if the exercise edit is cancelled.
- [x] 3.3 On an iPhone simulator, use 50 lb × 10 with 57.5 lb as the only heavier option. Verify Conservative offers 50 lb × 12, then select Aggressive, relaunch and verify an eligible exercise offers 57.5 lb × 10.

## 4. Integration verification

- [ ] 4.1 Format edited Swift files with xcrun swift-format. Run the repository-wide strict Swift lint and swift test --package-path TrainingKit with Xcode selected. Build the app and its extensions and report the macOS and simulator verification results.
