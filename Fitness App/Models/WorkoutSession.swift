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

    var volume: Double {
        WorkoutStats.volume(of: completedSets)
    }
}

@Model
final class SessionExercise {
    var sortIndex: Int
    var exerciseName: String
    var restSeconds: Int

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
}

@Model
final class SetEntry {
    var sortIndex: Int
    /// Kilograms.
    var weight: Double
    var reps: Int
    var isCompleted: Bool
    var completedAt: Date?

    var sessionExercise: SessionExercise?

    init(sortIndex: Int, weight: Double, reps: Int) {
        self.sortIndex = sortIndex
        self.weight = weight
        self.reps = reps
        self.isCompleted = false
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
    ]
}

enum AppSettings {
    static let activeGymIDKey = "activeGymID"
}
