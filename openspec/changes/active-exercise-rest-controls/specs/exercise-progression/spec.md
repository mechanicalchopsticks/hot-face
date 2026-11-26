# Rest-time effort feedback

## ADDED Requirements

### Requirement: Optional one-tap feedback after an exercise
During an inter-exercise rest following exercise completion, the active view SHALL ask how the named completed exercise felt and offer Hard, OK and Easy inline. A single tap SHALL dismiss the prompt. Hard and Easy SHALL record the existing effort rating once. OK SHALL acknowledge the prompt without recording an effort value or changing progression. Responding SHALL be optional and leave the timer running.

#### Scenario: Browse before rating
- **WHEN** the user finishes press, postpones the suggested squat and taps Hard during that rest
- **THEN** press receives one Hard rating and the rest continues toward its original deadline
- **AND** choosing Easy instead records one Easy rating for press

#### Scenario: Neutral acknowledgment
- **WHEN** the user taps OK and continues browsing upcoming exercises during the same rest
- **THEN** the prompt stays dismissed, the completed exercise has no effort value and its balance is unchanged

#### Scenario: Continue without answering
- **WHEN** rest ends with the prompt unanswered
- **THEN** the next work is ready normally and the exercise receives no rating

#### Scenario: Rest between sets
- **WHEN** a set ends with more sets of the same exercise still to perform next
- **THEN** the exercise-completion feedback prompt is absent
