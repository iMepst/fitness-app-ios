import Foundation
import SwiftData

@Model
final class WorkoutSession {
    var startDate: Date
    /// `nil` while the workout is running.
    var endDate: Date?
    /// Snapshots so history stays readable after a plan or gym is deleted.
    var planName: String
    var gymName: String
    var notes: String = ""
    /// UUID of the workout saved to Apple Health, if any.
    var healthKitWorkoutID: UUID?

    var plan: WorkoutPlan?
    var gym: Gym?

    @Relationship(deleteRule: .cascade, inverse: \SessionExercise.session)
    var exercises: [SessionExercise] = []

    init(startDate: Date = .now, plan: WorkoutPlan?, gym: Gym?) {
        self.startDate = startDate
        self.planName = plan?.name ?? ""
        self.gymName = gym?.name ?? ""
        self.plan = plan
        self.gym = gym
    }

    var displayTitle: String {
        planName.isEmpty ? "Freies Training" : planName
    }

    var sortedExercises: [SessionExercise] {
        exercises.sorted { $0.sortIndex < $1.sortIndex }
    }

    var duration: TimeInterval {
        (endDate ?? .now).timeIntervalSince(startDate)
    }

    var completedSets: [SetEntry] {
        exercises.flatMap(\.sets).filter(\.isCompleted)
    }

    /// Completed sets without warm-ups.
    var workingSets: [SetEntry] {
        completedSets.filter(\.kind.countsAsWorkingSet)
    }

    var volume: Double {
        WorkoutStats.volume(of: completedSets)
    }
}

@Model
final class SessionExercise {
    var sortIndex: Int
    var exerciseName: String
    var restSeconds: Int
    var notes: String = ""
    /// Exercises sharing a group number form a superset.
    var supersetGroup: Int?
    /// Copied from the plan entry; used for weight suggestions.
    var targetRepsMin: Int?
    var targetRepsMax: Int?

    var exercise: Exercise?
    var session: WorkoutSession?

    @Relationship(deleteRule: .cascade, inverse: \SetEntry.sessionExercise)
    var sets: [SetEntry] = []

    init(exercise: Exercise, sortIndex: Int, restSeconds: Int) {
        self.exercise = exercise
        self.exerciseName = exercise.name
        self.sortIndex = sortIndex
        self.restSeconds = restSeconds
    }

    var sortedSets: [SetEntry] {
        sets.sorted { $0.sortIndex < $1.sortIndex }
    }

    /// Completed sets without warm-ups.
    var workingSets: [SetEntry] {
        sets.filter { $0.isCompleted && $0.kind.countsAsWorkingSet }
    }
}

@Model
final class SetEntry {
    var sortIndex: Int
    /// Kilograms.
    var weight: Double
    var reps: Int
    var isCompleted: Bool
    var completedAt: Date?
    var kindRaw: String = SetKind.normal.rawValue
    /// Rate of perceived exertion, 6–10 in half steps.
    var rpe: Double?

    var sessionExercise: SessionExercise?

    init(sortIndex: Int, weight: Double, reps: Int, kind: SetKind = .normal) {
        self.sortIndex = sortIndex
        self.weight = weight
        self.reps = reps
        self.isCompleted = false
        self.kindRaw = kind.rawValue
    }

    var kind: SetKind {
        get { SetKind(rawValue: kindRaw) ?? .normal }
        set { kindRaw = newValue.rawValue }
    }
}

enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        Gym.self,
        Exercise.self,
        WorkoutPlan.self,
        PlanEntry.self,
        WorkoutSession.self,
        SessionExercise.self,
        SetEntry.self,
        BodyWeightEntry.self,
    ]
}

enum AppSettings {
    static let activeGymIDKey = "activeGymID"
    static let barWeightKey = "barWeight"
    static let platesKey = "availablePlates"
    static let healthSyncKey = "healthSyncEnabled"
    static let weeklyGoalKey = "weeklyGoal"

    static let defaultBarWeight = 20.0
    static let defaultPlates = "25;20;15;10;5;2.5;1.25"
    static let defaultWeeklyGoal = 3
    /// Plates offered in Settings (kg).
    static let standardPlates: [Double] = [25, 20, 15, 10, 5, 2.5, 2, 1.25, 1, 0.5]

    /// Stored as "25;20;2.5" (always dot decimals, written by the app itself).
    static func parsePlates(_ text: String) -> [Double] {
        Array(Set(text.split(separator: ";").compactMap { Double($0) }.filter { $0 > 0 })).sorted(by: >)
    }

    static func encodePlates(_ plates: [Double]) -> String {
        plates.sorted(by: >).map { String($0) }.joined(separator: ";")
    }
}
