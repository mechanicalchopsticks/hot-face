import Foundation
import SwiftData
import TrainingDomain

private typealias V1 = TrainingSchemaV1

public struct RoutineCycle: Equatable, Sendable {
    public let id: UUID
    public let routineID: UUID
    public let orderedDayIDs: [UUID]
    public let completedDayIDs: [UUID]
    public let skippedDayIDs: [UUID]

    public var availableDayIDs: [UUID] {
        orderedDayIDs.filter { !completedDayIDs.contains($0) && !skippedDayIDs.contains($0) }
    }

    public var isComplete: Bool { availableDayIDs.isEmpty }

    fileprivate init(_ cycle: V1.Cycle) {
        id = cycle.id
        routineID = cycle.routineID
        orderedDayIDs = cycle.orderedDayIDs
        completedDayIDs = cycle.completedDayIDs
        skippedDayIDs = cycle.skippedDayIDs
    }
}

public enum RoutineCycleError: Error, Equatable {
    case missingRoutine, invalidDayOrder, dayUnavailable, openSession
}

extension CoordinatedModelStore {
    /// Returns the current cycle, creating a fresh cycle after all days have been completed or skipped.
    public func currentCycle(for routineID: UUID) throws -> RoutineCycle {
        try withContext { context in
            let routines = FetchDescriptor<V1.Routine>(predicate: #Predicate { $0.id == routineID })
            guard let routine = try context.fetch(routines).first, !routine.isArchived else {
                throw RoutineCycleError.missingRoutine
            }
            let dayIDs = try routine.plan.days.map(\.id)
            let cycles = try context.fetch(
                FetchDescriptor<V1.Cycle>(predicate: #Predicate { $0.routineID == routineID }))
            if let current = cycles.first(where: {
                !Set($0.completedDayIDs + $0.skippedDayIDs).isSuperset(of: dayIDs)
            }) {
                return RoutineCycle(current)
            }
            let cycle = V1.Cycle(routineID: routineID, orderedDayIDs: dayIDs)
            context.insert(cycle)
            try context.save()
            return RoutineCycle(cycle)
        }
    }

    /// Reorders only this cycle unless `keepForFutureCycles` is true.
    public func reorderDays(
        in cycleID: UUID, to orderedDayIDs: [UUID], keepForFutureCycles: Bool = false
    ) throws -> RoutineCycle {
        try withContext { context in
            let cycles = FetchDescriptor<V1.Cycle>(predicate: #Predicate { $0.id == cycleID })
            guard let cycle = try context.fetch(cycles).first else { throw RoutineCycleError.missingRoutine }
            guard Set(orderedDayIDs) == Set(cycle.orderedDayIDs), orderedDayIDs.count == cycle.orderedDayIDs.count
            else { throw RoutineCycleError.invalidDayOrder }
            cycle.orderedDayIDs = orderedDayIDs
            if keepForFutureCycles {
                let routineID = cycle.routineID
                let routines = FetchDescriptor<V1.Routine>(predicate: #Predicate { $0.id == routineID })
                guard let routine = try context.fetch(routines).first, !routine.isArchived else {
                    throw RoutineCycleError.missingRoutine
                }
                var plan = try routine.plan
                let daysByID = Dictionary(uniqueKeysWithValues: plan.days.map { ($0.id, $0) })
                plan.days = try orderedDayIDs.map {
                    guard let day = daysByID[$0] else { throw RoutineCycleError.invalidDayOrder }
                    return day
                }
                try routine.replacePlan(plan)
            }
            try context.save()
            return RoutineCycle(cycle)
        }
    }

    public func skipDay(_ dayID: UUID, in cycleID: UUID) throws -> RoutineCycle {
        try withContext { context in
            let open = FetchDescriptor<V1.Session>(predicate: #Predicate { $0.finishedAt == nil })
            guard try context.fetchCount(open) == 0 else { throw RoutineCycleError.openSession }
            let cycles = FetchDescriptor<V1.Cycle>(predicate: #Predicate { $0.id == cycleID })
            guard let cycle = try context.fetch(cycles).first,
                cycle.orderedDayIDs.contains(dayID), !cycle.completedDayIDs.contains(dayID),
                !cycle.skippedDayIDs.contains(dayID)
            else { throw RoutineCycleError.dayUnavailable }
            cycle.skippedDayIDs.append(dayID)
            try context.save()
            return RoutineCycle(cycle)
        }
    }
}
