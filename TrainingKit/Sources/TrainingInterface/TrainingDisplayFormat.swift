import Foundation
import TrainingDomain

public enum TrainingDisplayFormat {
    public static func load(_ load: ExerciseLoad, locale: Locale) -> String {
        let amount = load.amount.formatted(.number.locale(locale))
        return "\(amount) \(load.unit.rawValue)"
    }

    public static func date(_ date: Date, locale: Locale, timeZone: TimeZone = .autoupdatingCurrent) -> String {
        date.formatted(Date.FormatStyle(date: .numeric, time: .omitted, locale: locale, timeZone: timeZone))
    }
}
