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
