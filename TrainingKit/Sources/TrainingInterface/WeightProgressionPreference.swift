import SwiftUI
import TrainingDomain

@propertyWrapper
public struct WeightProgressionPreference: DynamicProperty {
    static let key = "weightProgressionMode"
    @AppStorage private var storedMode: WeightProgressionMode

    public init(store: UserDefaults = .standard) {
        _storedMode = AppStorage(wrappedValue: .conservative, Self.key, store: store)
    }

    public var wrappedValue: WeightProgressionMode {
        get { storedMode }
        nonmutating set { storedMode = newValue }
    }

    public var projectedValue: Binding<WeightProgressionMode> { $storedMode }
}
