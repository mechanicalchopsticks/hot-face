# Tasks

## 1. Photo import and review

- [ ] 1.1 Test review of a preloaded draft in Routines based on the analyzed photos. Walk through the days, correct a prescription, and inspect the editor result using sample data; refine the UI with the user before integrating extraction and saving.
- [ ] 1.2 Define a structured extraction contract and reviewable draft. Validate synthetic examples covering both sides of the sheet, uncertain fields, and combined repetitions.
- [ ] 1.3 Evaluate the visual extraction provider, cost, and image handling. Deliver a comparison and review the selection with the user before enabling paid services.
- [ ] 1.4 Implement a minimal authenticated service and adapter. Keep keys out of the client and images out of logs. Test invalid requests, limits, timeouts, and retries.
- [ ] 1.5 Evaluate extraction with rutina1 and rutina3 as authorized local samples. Verify differing legends, numbering, a crossed-out station, uncolored handwritten entries, and the distinction between MAQ and load.
- [ ] 1.6 Implement editable review by day with an image reference. Verify corrections to order, names, times, per-side indications, and segments before saving.
- [ ] 1.7 Implement the configurable gym convention that tentatively assigns abdominal exercises without a day to Day 1 for confirmation. Test that an explicit day takes priority and that other gyms do not use the convention by default.
- [ ] 1.8 Integrate the reviewed draft with the routine editor and manual supersets. Verify that a missing load is filled only through user input or confirmation of a historical suggestion. Complete import, edit, and offline training and document what to review.
