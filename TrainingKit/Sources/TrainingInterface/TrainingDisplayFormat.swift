import Foundation
import TrainingDomain

public enum TrainingDisplayFormat {
    public static func toFailure(locale: Locale) -> LocalizedStringResource {
        LocalizedStringResource("To failure", locale: locale, bundle: .atURL(Bundle.module.bundleURL))
    }

    public static func prescription(_ exercise: ExercisePrescription, sets: Int, locale: Locale) -> String {
        let segments = exercise.segments.map { segment in
            switch segment {
            case .repetitions(let reps): reps.formatted(.number.locale(locale))
            case .seconds(let seconds): seconds.formatted(.number.locale(locale)) + " s"
            case .toFailure: String(localized: toFailure(locale: locale))
            }
        }
        let sequence = segments.joined(separator: "+")
        return "\(sets.formatted(.number.locale(locale))) × " + (segments.count > 1 ? "(\(sequence))" : sequence)
    }
    public static func load(_ load: ExerciseLoad, locale: Locale) -> String {
        let amount = load.amount.formatted(.number.locale(locale))
        return "\(amount) \(load.unit.rawValue)"
    }

    public static func date(_ date: Date, locale: Locale, timeZone: TimeZone = .autoupdatingCurrent) -> String {
        date.formatted(Date.FormatStyle(date: .numeric, time: .omitted, locale: locale, timeZone: timeZone))
    }

    public static func editableWeight(_ weight: Decimal, locale: Locale) -> String {
        weight.formatted(.number.locale(locale).grouping(.never).precision(.fractionLength(0...128)))
    }

    public static func parseWeight(_ text: String, locale: Locale) -> Decimal? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = text.components(separatedBy: locale.decimalSeparator ?? ".")
        let digits = parts.joined().unicodeScalars
        // Foundation's number parser can accept only the prefix even in strict mode.
        guard parts.count <= 2, !digits.isEmpty, digits.allSatisfy(CharacterSet.decimalDigits.contains) else {
            return nil
        }
        let style = Decimal.FormatStyle(locale: locale).grouping(.never)
        return try? Decimal(text, format: style, lenient: false)
    }
}

extension WeightSuggestion.Reason {
    public var explanation: LocalizedStringResource {
        switch self {
        case .higherLoad:
            LocalizedStringResource(
                "Use the next available load and keep the same repetitions.", bundle: .atURL(Bundle.module.bundleURL))
        case .lowerLoad:
            LocalizedStringResource(
                "The effort balance is low. Use the next lighter load.", bundle: .atURL(Bundle.module.bundleURL))
        case .fewerRepetitions:
            LocalizedStringResource(
                "At the lightest load, move down one repetition step.", bundle: .atURL(Bundle.module.bundleURL))
        case .moreRepetitions:
            LocalizedStringResource(
                "At the heaviest load, move up one repetition step.", bundle: .atURL(Bundle.module.bundleURL))
        case .prepareIncrease:
            LocalizedStringResource(
                "The next load is over 10% heavier. Increase repetitions first.",
                bundle: .atURL(Bundle.module.bundleURL))
        case .completeBridge:
            LocalizedStringResource(
                "You completed the repetition step. Increase the load and return to the preceding step.",
                bundle: .atURL(Bundle.module.bundleURL))
        case .increaseAfterFifteen:
            LocalizedStringResource(
                "At 15 repetitions, move to the next load with 10 repetitions.", bundle: .atURL(Bundle.module.bundleURL)
            )
        }
    }
}
