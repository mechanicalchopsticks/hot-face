import Testing

@testable import TrainingInterface

struct DurationSelectionTests {
    @Test(arguments: [(4500, 1...3600), (630, 0...600)])
    func displaysStoredDurationUntilSelectingAReplacement(stored: Int, range: ClosedRange<Int>) {
        let selection = DurationSelection(seconds: stored, range: range)
        #expect(selection.outOfRangeSeconds == stored)
        let replacement = selection.total(selectingMinutes: range.upperBound / 60)
        #expect(replacement == range.upperBound)
        #expect(DurationSelection(seconds: replacement, range: range).outOfRangeSeconds == nil)
    }

    @Test(arguments: [0...600, 1...3600])
    func minuteAndSecondLimits(range: ClosedRange<Int>) {
        let short = DurationSelection(seconds: 59, range: range)
        #expect(short.minutes == 0)
        #expect(short.seconds == 59)
        #expect(short.availableSeconds == range.lowerBound...59)
        #expect(short.total(selectingMinutes: range.upperBound / 60) == range.upperBound)
        let maximum = DurationSelection(seconds: range.upperBound, range: range)
        #expect(maximum.availableSeconds == 0...0)
        #expect(maximum.total(selectingMinutes: 0) == range.lowerBound)
    }
}
