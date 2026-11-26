import Foundation
import Testing

@testable import TrainingInterface

struct WeightProgressionPreferenceTests {
    @Test func restoresTheModeAndFallsBackForUnknownValues() throws {
        let suite = UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(WeightProgressionPreference(store: defaults).wrappedValue == .conservative)
        defaults.set("unknown", forKey: WeightProgressionPreference.key)
        let preference = WeightProgressionPreference(store: defaults)
        #expect(preference.wrappedValue == .conservative)
        preference.wrappedValue = .aggressive
        let reopened = try #require(UserDefaults(suiteName: suite))
        #expect(WeightProgressionPreference(store: reopened).wrappedValue == .aggressive)
    }
}
