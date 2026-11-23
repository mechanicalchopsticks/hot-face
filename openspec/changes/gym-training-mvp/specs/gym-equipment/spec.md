## Purpose

Represent each gym's equipment and the loads the user chooses, preserving units, estimates and display conventions.

## ADDED Requirements

### Requirement: Changing gyms
The app SHALL let users create and edit gyms and select an active gym. Changing gyms SHALL archive the active routine and start creating a new one with zero effort balances. History SHALL retain its original gym.

#### Scenario: Return to a familiar gym
- **WHEN** the user returns to a previous gym
- **THEN** the app starts a new routine, which the user may copy from an archived routine, and leaves the old routine archived

### Requirement: Deleting a gym
The app SHALL allow gym deletion from Settings. Before confirmation, it SHALL identify the gym and explain that it will become unavailable for training and its history will remain accessible. Cancelling SHALL preserve the catalog and current selection.

#### Scenario: Delete an inactive gym
- **WHEN** the user confirms deletion of an inactive gym
- **THEN** the gym and its equipment disappear from pickers, including after reopening the app
- **AND** the active gym and routine remain selected, and sessions and archived routines from the deleted gym remain accessible with their original gym and equipment

#### Scenario: Delete the active gym
- **WHEN** the user deletes the active gym while other gyms remain
- **THEN** the user chooses a replacement before confirming, the app archives any active routine and starts creating a routine with zero balances in the selected gym
- **AND** if a session is open in the gym being deleted, the user can continue or finish it and can confirm deletion only after finishing it

#### Scenario: Delete the last gym
- **WHEN** the user finishes any open session and confirms deletion of the only gym
- **THEN** the app archives any active routine and Settings shows an empty catalog with an option to create a gym
- **AND** history remains accessible and creating a gym with the same name gives it a new identity

### Requirement: Available equipment
The app SHALL support dumbbells, barbells with plates, fixed bars, selectorized machines, plate-loaded machines, bodyweight, resistance bands and cardio. Available loads SHALL reflect the selected gym's equipment.

#### Scenario: Select equipment
- **WHEN** two exercises in the same gym use barbells or plate-loaded machines
- **THEN** both use the same plate sizes and each exercise retains its own usual load

### Requirement: Generic equipment in each gym
The exercise equipment picker SHALL offer one generic option for each of the eight supported equipment types in every gym, including previously saved gyms. Each option SHALL be usable immediately and follow the same load selection rules as specific equipment of that type. Users SHALL be able to add specific equipment alongside the generic options and assign it to individual exercises.

#### Scenario: Prescribe an exercise in a new gym
- **WHEN** the user creates a gym and edits an exercise before adding any specific equipment
- **THEN** the picker offers all eight generic options, and choosing the generic barbell lets the user select a load reachable with that gym's plates

#### Scenario: Add a specific barbell later
- **WHEN** two exercises use the generic barbell and the user registers a barbell at station 3 and assigns it to one exercise
- **THEN** that exercise uses the station 3 barbell, the other retains the generic barbell, and both options remain available after reopening

#### Scenario: Open an existing gym
- **WHEN** the user reopens a previously saved gym with custom equipment and edited weights
- **THEN** the picker offers each generic type once alongside the existing equipment, and existing assignments, inventories and historical sessions are preserved

### Requirement: Selecting resistance bands by color
For generic and specific resistance band equipment, the exercise editor SHALL let the user select a band by color without registering each color as equipment. The selector SHALL show a swatch and a localized name for each color: red, orange, yellow, green, blue, purple, brown, pink, light blue, white, light gray, dark gray and black. The selected color SHALL be saved per exercise, independently of numeric load.

#### Scenario: Choose different bands for two exercises
- **WHEN** the user selects the same band equipment for two exercises and chooses pink for one and light blue for the other
- **THEN** after saving and reopening the routine, each exercise shows its selected swatch and name in the current interface language
- **AND** neither selection requires a numeric resistance or a separate equipment entry

### Requirement: Deleting specific equipment
The app SHALL support deleting a specific equipment item in its gym's Settings. Before confirmation, it SHALL identify the item and its gym. Cancelling SHALL preserve the item and its assignments.

#### Scenario: Remove a machine from the catalog
- **WHEN** the user confirms deletion of a machine
- **THEN** the machine disappears from the catalog and equipment pickers, including after reopening the app
- **AND** shared inventories, other equipment and historical records retain their original values, including station, loads and units

#### Scenario: Delete equipment assigned to an exercise
- **WHEN** the user deletes equipment used by a current routine
- **THEN** the exercise retains its prescription and identifies the equipment as deleted so the user can replace it before using the exercise again
- **AND** an open session retains its original prescription snapshot and can be completed

### Requirement: Editable initial inventory per gym
Each new gym SHALL start with editable inventories of plates, individual dumbbells and fixed bars. Users SHALL be able to add, edit and remove weights in the gym's Settings. Each exercise SHALL offer choices from the inventory for its equipment. Each entry SHALL retain its original unit.

#### Scenario: Create a gym
- **WHEN** the user creates a gym
- **THEN** its inventories contain these initial weights

| Inventory | Initial weights |
|---|---|
| Plates (lb) | 2.5, 5, 10, 25, 35, 45 |
| Individual dumbbells (lb) | 2.5, 5, 10, 15, 20, 25, 30, 35, 40, 50, 60, 70, 80, 90, 100 |
| Individual dumbbells (kg) | 5, 7.5, 10, 12.5 |
| Fixed bars (EZ bar), total weight (kg) | 10, 15, 20, 25, 30, 35, 40, 50 |

#### Scenario: Share an inventory edit
- **WHEN** the user adds a 22.5 lb dumbbell and removes the 2.5 and 5 lb plates from a gym
- **THEN** all its dumbbell exercises offer 22.5 lb and its barbells and plate-loaded machines calculate loads with the remaining sizes
- **AND** other gyms retain their own inventory values

#### Scenario: Choose a dumbbell or fixed bar
- **WHEN** the user configures an exercise with the initial inventory
- **THEN** the dumbbell choices include both a 10 lb piece and a 10 kg piece, and the fixed bar choices include a bar with a total weight of 10 kg

### Requirement: Reachable plate loads
The load picker and progression suggestions SHALL use symmetric loads reachable with the gym's plate sizes. Each size is recorded once and can be repeated in the sum. The user chooses the physical combination that fits. The inclusive maximum SHALL be 500 lb added across both sides, subject to the equipment's optional maximum added load per side.

#### Scenario: Configure a barbell's base weight
- **WHEN** the user adds a barbell with plates
- **THEN** its base weight starts at 45 lb and can be edited independently of the added-load limits

#### Scenario: Distinguish reachable loads
- **WHEN** a barbell or plate-loaded machine uses the initial inventory and accepts at least 30 lb added
- **THEN** the picker and progression offer 30 lb added (10 + 5 lb per side) and exclude 31 lb added as unreachable

#### Scenario: Apply the equipment limit and base weight
- **WHEN** a 45 lb barbell accepts up to 90 lb added per side
- **THEN** it accepts two 45 lb plates per side, equivalent to 180 lb added or 225 lb including the bar, and excludes added loads above 180 lb
- **AND** with the initial inventory and no equipment-specific maximum, it accepts 500 lb added (545 lb including the bar) and excludes 505 lb added

### Requirement: Selectorized machines with 5 kg increments
For a selectorized machine with 5 kg increments, the app SHALL offer the 30 loads from 5 through 150 kg inclusive in steps of 5 kg.

#### Scenario: Choose a selectorized machine load
- **WHEN** the user selects this machine for an exercise
- **THEN** the picker includes 5, 10 and 150 kg and excludes 0, 7.5 and 155 kg regardless of the plate inventory

### Requirement: Load representation per exercise
The app SHALL store the unit (kg or lb) and representation per exercise: per dumbbell or combined total, per side or total added, and total including the bar or equipment when its base weight is known. Changing representation SHALL preserve physical load and effort balance.

#### Scenario: Two dumbbells
- **WHEN** the user switches from 10 kg per dumbbell to the combined total for two dumbbells
- **THEN** the app shows 20 kg and preserves the progression record and balance

#### Scenario: Unknown barbell weight
- **WHEN** the user requests a total including a barbell whose weight is undefined
- **THEN** the app prompts the user to define that weight before displaying the total

### Requirement: Estimated loads and confirmation
The app SHALL distinguish undefined, estimated and confirmed usual loads. Training with an estimate SHALL record the actual value used and leave confirmation to the user.

#### Scenario: First set with an estimate
- **WHEN** the user completes a set with an estimated 20 lb
- **THEN** the set records 20 lb and the estimate remains until explicitly confirmed

#### Scenario: Missing weight
- **WHEN** an imported exercise has no initial weight
- **THEN** its load remains undefined and distinguishable from an explicit zero

### Requirement: Initial load from gym history
When creating a routine, the app SHALL work offline to suggest the load from the most recent performed set with a recorded weight for an exercise of the same name in the same gym. The search SHALL include archived routines and partially completed sessions. The user SHALL be able to confirm the load, edit it before confirming or leave it undefined.

#### Scenario: Most recent valid set across routines
- **WHEN** the last recorded set for that name in the gym was 35 kg in a partial session three routines ago, a later session skipped the exercise and another gym recorded 40 kg
- **THEN** the app suggests 35 kg even if the station, variant or repetitions have changed

#### Scenario: Context for the decision
- **WHEN** the previous exercise prescribed 4 × (7+7+7) with 35 kg and the new one prescribes 3 × 8
- **THEN** the app shows both prescriptions, the previous date, the load with its unit and any previous station and instructions, and omits the gym name
- **AND** if the user edits the suggestion to 30 kg and confirms, the exercise saves 30 kg as its initial load and its new balance starts at zero

#### Scenario: No history in this gym
- **WHEN** a new exercise lacks an initial load and has weighted sets only in another gym
- **THEN** the load remains undefined
