# exercise-progression Specification

## Purpose

Offer reproducible progression suggestions based on voluntary effort ratings and available equipment. The user decides whether to accept each suggestion.

## Requirements

### Requirement: Effort balance
The app SHALL maintain a balance from −2 to +2. Easy adds one and Hard subtracts one, saturating at the limits. Omitting a rating SHALL preserve the balance. Users SHALL be able to rate partially performed exercises and sessions with temporary adjustments.

#### Scenario: Opposite rating
- **WHEN** the balance is +2 and the user rates the exercise Hard
- **THEN** the balance becomes +1 and the increase suggestion disappears

#### Scenario: Missing rating and upper limit
- **WHEN** the ratings are Easy, omitted, Easy and Easy
- **THEN** the successive balances are +1, +1, +2 and +2

### Requirement: Reset on usual changes
Changing the usual weight, repetitions, sets or duration, accepting a suggestion or permanently replacing an exercise SHALL reset the balance. Temporary adjustments, reordering, notes and display conversions SHALL preserve it.

#### Scenario: Rating a temporary adjustment
- **WHEN** the balance is +1 and the user rates the exercise Easy after using a temporary load
- **THEN** the balance becomes +2 and the usual prescription is preserved

### Requirement: Editable suggestion at exercise start
At +2 or −2, the app SHALL suggest a change at exercise start based on the usual prescription and available loads. Users SHALL be able to edit it before confirmation. Acceptance SHALL save the final values as usual, record the change and reset the balance. Continuing with current values SHALL preserve the balance.

#### Scenario: Decline and return
- **WHEN** the user continues with current values and the balance stays at +2
- **THEN** the suggestion appears at the next start without requiring two more ratings

#### Scenario: Customize a suggestion
- **WHEN** the app suggests 35 lb × 12 and the user confirms 35 lb × 11
- **THEN** it saves 35 lb × 11 as usual and resets the balance to zero

#### Scenario: Use the usual prescription
- **WHEN** a previous session used a temporary 25 lb × 15 and the usual prescription is 35 lb × 10
- **THEN** the app calculates the suggestion from 35 lb × 10

### Requirement: Small load increase
At +2, if the next available load increases weight by at most 10% inclusive, the app SHALL suggest that load with the same repetitions.

#### Scenario: Small increase
- **WHEN** the usual prescription is 50 lb × 15 and the next load is 52.5 lb
- **THEN** it suggests 52.5 lb × 15

#### Scenario: Inclusive threshold
- **WHEN** the usual prescription is 50 lb × 10 and the next load is 55 lb
- **THEN** it suggests 55 lb × 10

### Requirement: Intermediate repetition step
For a load increase above 10%, the app SHALL first suggest the next repetition step among 8, 10, 12 and 15 at the same load if a higher step exists. Accepting that step SHALL establish a bridge. At the next +2, it SHALL suggest the higher load with the repetition step preceding the accepted target. Accepting a different physical load or repetition count SHALL clear the bridge and establish the edited values as the new baseline.

#### Scenario: Bridge from ten to twelve
- **WHEN** the user starts at 35 lb × 10, the next load is 45 lb and the user accepts 35 lb × 12
- **THEN** the next +2 suggests 45 lb × 10

#### Scenario: Recalculate after an edited bridge
- **WHEN** the user edits 35 lb × 12 to 35 lb × 11 and accepts it
- **THEN** the next +2 suggests 35 lb × 12
- **AND** accepting it and reaching +2 again suggests 45 lb × 10, the step preceding 12

#### Scenario: Bridge from twelve to fifteen
- **WHEN** the user accepts the step from 12 to 15 repetitions to prepare for a heavier load
- **THEN** the next +2 suggests the higher load with 12 repetitions

#### Scenario: Fifteen without a previous bridge
- **WHEN** the usual count is 15 without a previous bridge and the next load increases weight by more than 10%
- **THEN** the app suggests the next load with 10 repetitions

### Requirement: Load limits and repetition steps
At +2 with zero added load, the app SHALL suggest the smallest available positive added load and preserve repetitions. Without a higher load it SHALL suggest the next repetition step up to 15, or invite manual adjustment if none exists. For off-step counts it SHALL select the next step in the corresponding direction.

#### Scenario: Nine repetitions
- **WHEN** an increase in repetitions is due from 9
- **THEN** the app suggests 10, and a decrease from 9 suggests 8

#### Scenario: No higher load
- **WHEN** no higher load exists and the usual count is 12
- **THEN** the app suggests 15 at the same load, or invites manual adjustment if the count is already 15

### Requirement: Decrease after difficulty
At −2, the app SHALL prefer the next lower load and preserve repetitions. Without a lower load it SHALL use the next lower repetition step among 15, 12, 10, 8 and 6, or invite manual adjustment if no lower step is available.

#### Scenario: Minimum load
- **WHEN** no lower load exists and the usual count is 10
- **THEN** the app suggests 8 at the same load

#### Scenario: Lower limit
- **WHEN** no lower load exists and the usual count is 6
- **THEN** the app invites manual adjustment without suggesting numeric values

### Requirement: Per-side percentages
For per-side loads, the app SHALL calculate the percentage using added weight per side, excluding the bar or equipment regardless of display representation.

#### Scenario: Exclude the bar
- **WHEN** the added load increases from 10 kg per side to 12.5 kg per side
- **THEN** the increase is 25% even if the bar weighs 20 kg

### Requirement: Special manual adjustments
Set counts SHALL always be adjusted manually. At either balance limit, timed exercises and combined repetition segments SHALL invite manual adjustment without suggesting numeric values.

#### Scenario: Combined repetitions
- **WHEN** a 7+7+7 exercise reaches +2
- **THEN** the app invites manual review while preserving the segments and omitting numeric suggestions
