import SwiftUI

public struct DurationPicker: View {
    let title: LocalizedStringKey
    @Binding var seconds: Int
    let range: ClosedRange<Int>

    public init(_ title: LocalizedStringKey, seconds: Binding<Int>, range: ClosedRange<Int>) {
        self.title = title
        _seconds = seconds
        self.range = range
    }

    public var body: some View {
        let selection = DurationSelection(seconds: seconds, range: range)
        VStack(alignment: .leading) {
            Text(title)
            HStack {
                Picker(
                    LocalizedStringKey("Minutes"),
                    selection: Binding(
                        get: { selection.minutes },
                        set: {
                            seconds = selection.total(selectingMinutes: $0)
                        })
                ) {
                    ForEach(range.lowerBound / 60...range.upperBound / 60, id: \.self) { Text($0.formatted()) }
                }
                .accessibilityIdentifier("durationMinutes")
                Picker(
                    "Seconds",
                    selection: Binding(get: { selection.seconds }, set: { seconds = selection.minutes * 60 + $0 })
                ) {
                    ForEach(selection.availableSeconds, id: \.self) { Text($0.formatted()) }
                }
                .accessibilityIdentifier("durationSeconds")
            }.pickerStyle(.menu)
        }
    }
}

struct DurationSelection {
    let range: ClosedRange<Int>
    let minutes: Int
    let seconds: Int

    init(seconds: Int, range: ClosedRange<Int>) {
        self.range = range
        let total = min(max(seconds, range.lowerBound), range.upperBound)
        minutes = total / 60
        self.seconds = total % 60
    }

    var availableSeconds: ClosedRange<Int> {
        max(0, range.lowerBound - minutes * 60)...min(59, range.upperBound - minutes * 60)
    }

    func total(selectingMinutes value: Int) -> Int {
        min(max(value * 60 + seconds, range.lowerBound), range.upperBound)
    }
}
