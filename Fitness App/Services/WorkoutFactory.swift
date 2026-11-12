import Foundation
import SwiftData

/// Creates and finishes workout sessions.
enum WorkoutFactory {
    static func startSession(plan: WorkoutPlan?, gym: Gym?, in context: ModelContext) -> WorkoutSession {
        let session = WorkoutSession(plan: plan, gym: gym)
        context.insert(session)
        if let plan {
            for entry in plan.sortedEntries {
                guard let exercise = entry.exercise else { continue }
                addExercise(
                    exercise,
                    to: session,
                    targetSets: entry.targetSets,
                    defaultReps: entry.repsMin,
                    restSeconds: entry.restSeconds,
                    supersetGroup: entry.supersetGroup,
                    targetReps: entry.repsMin...max(entry.repsMin, entry.repsMax),
                    in: context
                )
            }
        }
        try? context.save()
        return session
    }

    /// Adds an exercise with sets prefilled from the last finished session
    /// (falls back to the plan's targets).
    @discardableResult
    static func addExercise(
        _ exercise: Exercise,
        to session: WorkoutSession,
        targetSets: Int? = nil,
        defaultReps: Int = 10,
        restSeconds: Int = 90,
        supersetGroup: Int? = nil,
        targetReps: ClosedRange<Int>? = nil,
        in context: ModelContext
    ) -> SessionExercise {
        let nextIndex = (session.exercises.map(\.sortIndex).max() ?? -1) + 1
        let entry = SessionExercise(exercise: exercise, sortIndex: nextIndex, restSeconds: restSeconds)
        entry.supersetGroup = supersetGroup
        entry.targetRepsMin = targetReps?.lowerBound
        entry.targetRepsMax = targetReps?.upperBound
        context.insert(entry)
        session.exercises.append(entry)

        let previous = WorkoutStats.lastPerformance(of: exercise, excluding: session)?
            .sortedSets.filter(\.isCompleted) ?? []
        let count = max(targetSets ?? (previous.isEmpty ? 3 : previous.count), 1)

        for index in 0..<count {
            let template = previous.isEmpty ? nil : previous[min(index, previous.count - 1)]
            let set = SetEntry(
                sortIndex: index,
                weight: template?.weight ?? 0,
                reps: template?.reps ?? defaultReps,
                kind: template?.kind ?? .normal
            )
            context.insert(set)
            entry.sets.append(set)
        }
        return entry
    }

    static func addSet(to entry: SessionExercise, in context: ModelContext) {
        let last = entry.sortedSets.last
        let set = SetEntry(
            sortIndex: (last?.sortIndex ?? -1) + 1,
            weight: last?.weight ?? 0,
            reps: last?.reps ?? 10,
            // Drop sets usually come in a row; everything else continues as a working set.
            kind: last?.kind == .drop ? .drop : .normal
        )
        context.insert(set)
        entry.sets.append(set)
    }

    static func remove(_ set: SetEntry, from entry: SessionExercise, in context: ModelContext) {
        entry.sets.removeAll { $0.persistentModelID == set.persistentModelID }
        context.delete(set)
    }

    static func remove(_ entry: SessionExercise, from session: WorkoutSession, in context: ModelContext) {
        session.exercises.removeAll { $0.persistentModelID == entry.persistentModelID }
        context.delete(entry)
        Supersets.cleanUp(session.exercises)
    }

    /// Drops unfinished sets and empty exercises, then marks the session finished.
    /// Returns `false` (and changes nothing) if no set was completed.
    @discardableResult
    static func finish(_ session: WorkoutSession, in context: ModelContext) -> Bool {
        guard !session.completedSets.isEmpty else { return false }
        for entry in session.exercises {
            for set in entry.sets where !set.isCompleted {
                remove(set, from: entry, in: context)
            }
        }
        for entry in session.exercises where entry.sets.isEmpty {
            remove(entry, from: session, in: context)
        }
        session.endDate = .now
        try? context.save()
        return true
    }

    static func discard(_ session: WorkoutSession, in context: ModelContext) {
        context.delete(session)
        try? context.save()
    }
}
