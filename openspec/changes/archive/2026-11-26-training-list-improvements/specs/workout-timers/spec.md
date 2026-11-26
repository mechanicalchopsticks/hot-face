## ADDED Requirements

### Requirement: Configure and display durations in minutes and seconds
Duration editors, including in-session adjustments, SHALL provide minute and second selectors with maximum totals of 10:00 for rests and 60:00 for other durations. Duration displays throughout the app and Live Activity SHALL use minutes and two-digit seconds.

#### Scenario: Select a maximum
- **WHEN** the user selects ten minutes for a rest or sixty minutes for another duration
- **THEN** zero is the only selectable seconds value at that maximum

#### Scenario: Observe a running countdown
- **WHEN** a timer has 75 seconds remaining
- **THEN** the app and Live Activity display 1:15
