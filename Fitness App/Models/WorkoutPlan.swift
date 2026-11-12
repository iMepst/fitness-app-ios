import Foundation
import SwiftData

@Model
final class WorkoutPlan {
    var name: String
    var sortIndex: Int
    var createdAt: Date
    /// `true` while the plan is being created in the "Neuer Plan" sheet and not yet saved.
    var isDraft: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \PlanEntry.plan)
    var entries: [PlanEntry] = []

    @Relationship(deleteRule: .nullify, inverse: \WorkoutSession.plan)
    var sessions: [WorkoutSession] = []

    init(name: String, sortIndex: Int) {
        self.name = name
        self.sortIndex = sortIndex
        self.createdAt = .now
    }

    var sortedEntries: [PlanEntry] {
        entries.sorted { $0.sortIndex < $1.sortIndex }
    }

    var lastPerformed: Date? {
        sessions.filter { $0.endDate != nil }.map(\.startDate).max()
    }

    /// Muscle groups trained by the plan, most sets first.
    var muscleGroups: [MuscleGroup] {
        var sets: [MuscleGroup: Int] = [:]
        for entry in entries {
            guard let muscle = entry.exercise?.muscleGroup else { continue }
            sets[muscle, default: 0] += entry.targetSets
        }
        return sets.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key.rawValue < $1.key.rawValue }.map(\.key)
    }

    /// In a rotation (Push/Pull/Beine …) the plan due next is the one done longest ago;
    /// plans never done come first. `nil` with fewer than two startable plans.
    static func next(in plans: [WorkoutPlan]) -> WorkoutPlan? {
        let startable = plans.filter { !$0.entries.isEmpty }
        guard startable.count > 1 else { return nil }
        return startable.min { a, b in
            switch (a.lastPerformed, b.lastPerformed) {
            case (nil, nil): a.sortIndex < b.sortIndex
            case (nil, _): true
            case (_, nil): false
            case let (x?, y?): x < y
            }
        }
    }
}

@Model
final class PlanEntry {
    var sortIndex: Int
    var targetSets: Int
    var repsMin: Int
    var repsMax: Int
    var restSeconds: Int
    /// Entries sharing a group number form a superset.
    var supersetGroup: Int?

    var exercise: Exercise?
    var plan: WorkoutPlan?

    init(sortIndex: Int, targetSets: Int = 3, repsMin: Int = 8, repsMax: Int = 12, restSeconds: Int = 90) {
        self.sortIndex = sortIndex
        self.targetSets = targetSets
        self.repsMin = repsMin
        self.repsMax = repsMax
        self.restSeconds = restSeconds
    }
}
