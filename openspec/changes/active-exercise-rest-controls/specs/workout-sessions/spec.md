# Active exercise transitions

## ADDED Requirements

### Requirement: Contextual Up Next card
The active workout SHALL identify whether the upcoming work is another set of the same exercise, a different exercise, or the next member of a superset. It SHALL name the exercise and show the applicable set or round.

#### Scenario: Rest within an exercise
- **WHEN** the first of three press sets ends and the second press set follows
- **THEN** the card identifies the next set as press, set 2 of 3, and offers no exercise postponement

#### Scenario: Change exercises
- **WHEN** press ends and squat follows after rest
- **THEN** the card identifies squat as the next exercise and shows its upcoming set

#### Scenario: Transition within a superset
- **WHEN** row follows press in round 2 of a three-round superset
- **THEN** the card identifies row as the next superset member and shows round 2 of 3 without inserting a rest between members

### Requirement: Circular postponement during inter-exercise rest
During an inter-exercise rest the user SHALL be able to tap Postpone on the card to select the next pending block in session order and wrap to the first. The selected block SHALL be performed next, with remaining blocks retaining their relative order. Browsing SHALL keep the workout view open and the rest deadline intact.

#### Scenario: Choose after several passes
- **WHEN** the pending order is A, B, C, D and the user repeatedly postpones
- **THEN** the card previews B, C, D, A and repeats in that order on further taps
- **AND** performing C leaves A, B, D in order, while performing B after postponing only A leaves A, C, D

#### Scenario: Postpone a superset
- **WHEN** the next block contains B and C in a superset and the user postpones it
- **THEN** the next eligible block appears and both members remain together in their original order
- **AND** after the user explicitly dissolves the superset, its pending exercises can be postponed individually

#### Scenario: One remaining block
- **WHEN** only one eligible block remains
- **THEN** the card displays it with no actionable Postpone control
