import Foundation

public enum WeightProgressionMode: String, CaseIterable, Sendable {
    case conservative, aggressive
}

public enum ProgressionAdvice: Equatable, Sendable {
    case adjustManually
    case suggested(WeightSuggestion)

    private static let repetitionSteps = [6, 8, 10, 12, 15]

    public static func evaluate(
        for usual: ExercisePrescription, balance: Int, equipment: EquipmentDescription?, inventory: GymInventory,
        returnRepetitions: Int? = nil, mode: WeightProgressionMode = .conservative
    ) -> Self? {
        guard balance == 2 || balance == -2 else { return nil }
        guard let equipment, usual.equipmentID == equipment.id, usual.segments.count == 1,
            case .repetitions(let repetitions) = usual.segments[0], let current = usual.load.value,
            let currentKilograms = try? current.addedKilograms(equipment: equipment)
        else { return .adjustManually }

        let candidates = inventory.weightedOptions(for: equipment, displayedLike: current)
        // A load saved from the picker may already be rounded by the conversion from kilograms to pounds.
        let kilograms = candidates.first { $0.load == current }?.kilograms ?? currentKilograms
        func suggest(_ load: ExerciseLoad, _ reps: Int, _ reason: WeightSuggestion.Reason, bridge: Int? = nil) -> Self {
            .suggested(.init(load: load, repetitions: reps, returnRepetitionsOnAcceptance: bridge, reason: reason))
        }
        let currentAvailable = candidates.contains { $0.kilograms == kilograms }
        if balance == -2 {
            if let lower = candidates.filter({ $0.kilograms < kilograms }).max(by: { $0.kilograms < $1.kilograms }) {
                return suggest(lower.load, repetitions, .lowerLoad)
            }
            guard currentAvailable, let step = repetitionSteps.last(where: { $0 < repetitions })
            else { return .adjustManually }
            return suggest(current, step, .fewerRepetitions)
        }

        let heavier = candidates.filter { $0.kilograms > kilograms }
        let higher = heavier.min { $0.kilograms < $1.kilograms }
        if let higher {
            if let returnRepetitions {
                // Older bridges recorded the exact starting count, which could fall between steps.
                let step = repetitionSteps.last(where: { $0 <= returnRepetitions }) ?? returnRepetitions
                return suggest(higher.load, step, .completeBridge)
            }
            if kilograms == 0 {
                return suggest(higher.load, repetitions, .higherLoad)
            }
            if let target = heavier.filter({ $0.kilograms * 10 <= kilograms * 11 }).max(by: {
                $0.kilograms < $1.kilograms
            }) {
                return suggest(target.load, repetitions, .higherLoad)
            }
            if mode == .aggressive, higher.kilograms * 100 <= kilograms * 115 {
                return suggest(higher.load, repetitions, .higherLoad)
            }
            if repetitions == 15 { return suggest(higher.load, 10, .increaseAfterFifteen) }
        }
        guard currentAvailable, let step = repetitionSteps.dropFirst().first(where: { $0 > repetitions })
        else { return .adjustManually }
        if higher != nil {
            let returnStep = repetitionSteps.last(where: { $0 < step }) ?? repetitions
            return suggest(current, step, .prepareIncrease, bridge: returnStep)
        }
        return suggest(current, step, .moreRepetitions)
    }
}

public struct WeightSuggestion: Equatable, Sendable {
    public enum Reason: String, Sendable {
        case lowerLoad, fewerRepetitions, higherLoad, completeBridge, increaseAfterFifteen, prepareIncrease,
            moreRepetitions
    }
    public let load: ExerciseLoad
    public let repetitions: Int
    public let returnRepetitionsOnAcceptance: Int?
    public let reason: Reason

    public static func increase(
        for usual: ExercisePrescription, balance: Int, equipment: EquipmentDescription, inventory: GymInventory,
        returnRepetitions: Int? = nil, mode: WeightProgressionMode = .conservative
    ) -> Self? {
        guard balance == 2,
            case .suggested(let suggestion) = ProgressionAdvice.evaluate(
                for: usual, balance: balance, equipment: equipment, inventory: inventory,
                returnRepetitions: returnRepetitions, mode: mode)
        else { return nil }
        return suggestion
    }
}
