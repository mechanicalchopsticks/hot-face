## Purpose

Forms preserve the text the user is composing and validate the value that will be stored.

## ADDED Requirements

### Requirement: Preserve draft text and trim on save
Forms SHALL preserve draft text during editing, trim surrounding whitespace and newlines on save, preserve internal spacing and reject required values that are empty after trimming.

#### Scenario: Enter a multiword value
- **WHEN** a user types a space between words
- **THEN** the space remains visible while composing the next word

#### Scenario: Save a padded value
- **WHEN** a user saves a value with boundary whitespace and two internal spaces
- **THEN** only the boundary whitespace is removed

#### Scenario: Save a blank required field
- **WHEN** a required field contains only whitespace and newlines
- **THEN** the form prevents saving
