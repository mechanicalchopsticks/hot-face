# app-localization Specification

## Purpose

Let people use the interface in their iPhone's language while preserving their training data and chosen units.

## Requirements

### Requirement: Spanish and English
The app SHALL offer its interface in Spanish and English and select the language according to the applicable iPhone language setting. It SHALL localize navigation, actions, errors, suggestions, accessibility text, notifications and Lock Screen controls.

#### Scenario: Devices using different languages
- **WHEN** a user opens the app in Spanish and his wife opens it on an iPhone set to English
- **THEN** each sees the interface in their own language, including Fácil/Easy and Difícil/Hard

### Requirement: Language-independent data and formatting
The app SHALL preserve entered or imported names and notes without translating them automatically. It SHALL format numbers and dates according to the locale while preserving the chosen load unit and stored value.

#### Scenario: Decimal load
- **WHEN** the English interface displays a load of 12,5 kg in a locale that uses a decimal point
- **THEN** it shows 12.5 kg without converting the load to lb or changing the effort balance

#### Scenario: Routine with custom text
- **WHEN** the interface language changes
- **THEN** the app preserves the user's exercise names, variants and notes verbatim
