# Exercise progression

## ADDED Requirements

### Requirement: Global weight progression preference
Settings SHALL offer Conservative and Aggressive alongside repetition and rest settings. The selection SHALL persist across launches and apply to all exercises. Users without a saved preference SHALL default to Conservative.

#### Scenario: Default on install or upgrade
- **WHEN** a new or existing user opens the app without a saved progression preference
- **THEN** Settings shows Conservative and weight suggestions use Conservative

#### Scenario: Apply the preference across exercises
- **WHEN** the user selects Aggressive, relaunches the app and starts a different exercise eligible for a weight increase
- **THEN** Settings shows Aggressive and the suggestion uses Aggressive

## MODIFIED Requirements

### Requirement: Small load increase
At +2 with positive usual load and no pending bridge, both modes SHALL suggest the highest available heavier load within a 10% increase and preserve repetitions. If no such load exists, Aggressive SHALL suggest the smallest available increase above 10% and at most 15%, preserving repetitions.

#### Scenario: Small increase
- **WHEN** the usual prescription is 50 lb × 15 and the next load is 52.5 lb
- **THEN** it suggests 52.5 lb × 15

#### Scenario: Inclusive threshold
- **WHEN** the usual prescription is 50 lb × 10 and the next load is 55 lb
- **THEN** it suggests 55 lb × 10

#### Scenario: Both modes favor the closest increase within 10%
- **WHEN** the usual load is 50 lb and the available heavier loads are 51, 53 and 55.5 lb
- **THEN** both modes suggest 53 lb with the usual repetitions

#### Scenario: Aggressive fallback includes 15%
- **WHEN** the usual prescription is 50 lb × 10 and the only heavier load is 57.5 lb
- **THEN** Aggressive suggests 57.5 lb × 10 and Conservative suggests 50 lb × 12

#### Scenario: Closest increase above the target
- **WHEN** the usual load is 50 lb and the only heavier loads are 56 and 57.5 lb
- **THEN** Aggressive suggests 56 lb with the usual repetitions

#### Scenario: Both modes use the bridge above 15%
- **WHEN** the usual prescription is 50 lb × 10 and the only heavier load is 58 lb
- **THEN** both modes suggest 50 lb × 12

### Requirement: Intermediate repetition step
If the next load exceeds the mode’s direct increase limit, the app SHALL first suggest the next higher repetition step among 8, 10, 12 and 15 at the usual load, when available. Accepting it SHALL establish a bridge. At the next +2, the app SHALL suggest the next load with the step preceding the accepted target. Accepting a different physical load or repetition count SHALL clear the bridge and set the edited values as the new baseline.

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
- **WHEN** the usual count is 15 without a previous bridge and the next load exceeds the direct increase limit for the selected mode
- **THEN** the app suggests the next load with 10 repetitions
