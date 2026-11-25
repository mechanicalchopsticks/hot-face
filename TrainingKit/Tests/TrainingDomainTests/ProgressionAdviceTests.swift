import Foundation
import Testing
import TrainingDomain

struct ProgressionAdviceTests {
    private let equipment = EquipmentDescription(name: "Dumbbell", kind: .dumbbell, unit: .lb)

    private func advice(
        _ balance: Int, segments: [ExerciseSegment], weights: [Int] = [35], returnRepetitions: Int? = nil
    ) -> ProgressionAdvice? {
        var inventory = GymInventory()
        inventory[.dumbbells] = weights.map { InventoryWeight(Decimal($0), .lb) }
        var exercise = ExercisePrescription(name: "Row", sets: 2, segments: segments)
        exercise.equipmentID = equipment.id
        exercise.load = .confirmed(.init(amount: 35, unit: .lb, representation: .perImplement, implementCount: 1))
        return ProgressionAdvice.evaluate(
            for: exercise, balance: balance, equipment: equipment, inventory: inventory,
            returnRepetitions: returnRepetitions)
    }

    @Test(arguments: [(2, 9, 10), (-2, 9, 8), (-2, 8, 6), (-2, 10, 8)])
    func stepsWhenLoadCannotChange(balance: Int, start: Int, expected: Int) throws {
        let result = advice(balance, segments: [.repetitions(start)])
        guard case .suggested(let suggestion) = result else {
            Issue.record("Expected a repetition step")
            return
        }
        #expect(suggestion.load.amount == 35)
        #expect(suggestion.repetitions == expected)
        #expect(suggestion.returnRepetitionsOnAcceptance == nil)
    }

    @Test func completesAnOlderOffStepBridge() {
        let result = advice(2, segments: [.repetitions(12)], weights: [35, 45], returnRepetitions: 11)
        guard case .suggested(let suggestion) = result else {
            Issue.record("Expected a completed repetition bridge")
            return
        }
        #expect(suggestion.load.amount == 45 && suggestion.repetitions == 10)
    }

    @Test func prefersNearestLowerLoad() {
        guard case .suggested(let suggestion) = advice(-2, segments: [.repetitions(6)], weights: [10, 30, 35]) else {
            Issue.record("Expected a lower load")
            return
        }
        #expect(suggestion.load.amount == 30 && suggestion.repetitions == 6)
    }

    @Test(arguments: [2, -2], [ExerciseLoad.Representation.perSide, .totalAdded, .includingEquipment])
    func progressesByOneKilogramOnAPoundBar(balance: Int, representation: ExerciseLoad.Representation) throws {
        var bar = EquipmentDescription(name: "Bar", kind: .barbell, unit: .lb)
        bar.baseWeight = 45
        var inventory = GymInventory()
        inventory[.plates] = [.init(1, .kg)]
        var exercise = ExercisePrescription(name: "Squat", sets: 1, segments: [.repetitions(10)])
        exercise.equipmentID = bar.id
        let current = ExerciseLoad(amount: 10, unit: .kg, representation: .perSide, implementCount: 2)
        let picker = try inventory.loadOptions(for: bar).map {
            try $0.displayed(as: representation, equipmentWeightInLoadUnit: bar.baseWeight)
        }
        let metric = try current.displayed(
            as: representation, equipmentWeightInLoadUnit: bar.unit.converted(45, to: .kg))
        for load in [metric, picker[10]] {
            exercise.load = .confirmed(load)
            let advice = ProgressionAdvice.evaluate(
                for: exercise, balance: balance, equipment: bar, inventory: inventory)
            guard case .suggested(let suggestion) = advice else {
                Issue.record("Expected the adjacent plate load")
                continue
            }
            #expect(suggestion.load == picker[balance == 2 ? 11 : 9])
            #expect(suggestion.repetitions == 10)
            #expect(suggestion.reason == (balance == 2 ? .higherLoad : .lowerLoad))
        }
    }

    @Test func manualAdjustmentAtLimitsAndForSpecialExercises() {
        #expect(advice(-2, segments: [.repetitions(6)]) == .adjustManually)
        #expect(advice(2, segments: [.repetitions(15)]) == .adjustManually)
        for balance in [-2, 2] {
            #expect(advice(balance, segments: [.seconds(30)]) == .adjustManually)
            #expect(advice(balance, segments: Array(repeating: .repetitions(7), count: 3)) == .adjustManually)
            #expect(advice(balance, segments: [.toFailure]) == .adjustManually)
            #expect(advice(balance, segments: [.repetitions(9)], weights: []) == .adjustManually)
        }
        #expect(advice(1, segments: [.repetitions(9)]) == nil)
    }
}
