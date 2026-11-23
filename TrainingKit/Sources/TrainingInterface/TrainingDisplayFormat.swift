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
