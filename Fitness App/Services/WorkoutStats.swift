import Foundation
import SwiftData

struct ProgressPoint: Identifiable {
    let id: PersistentIdentifier
    let date: Date
    let topWeight: Double
    let estimatedOneRepMax: Double
}

/// Pure calculations over workout data.
enum WorkoutStats {
    /// Epley formula. Returns the weight itself for a single rep.
    static func estimatedOneRepMax(weight: Double, reps: Int) -> Double {
        guard reps > 0 else { return 0 }
        if reps == 1 { return weight }
        return weight * (1 + Double(reps) / 30)
    }

    /// Volume of completed working sets (warm-ups excluded).
    static func volume(of sets: [SetEntry]) -> Double {
        sets.filter { $0.isCompleted && $0.kind.countsAsWorkingSet }
            .reduce(0) { $0 + $1.weight * Double($1.reps) }
    }

    /// Universal exercises plus the machines of the active gym.
    static func available(_ exercises: [Exercise], activeGym: Gym?) -> [Exercise] {
        exercises.filter { exercise in
            guard let gym = exercise.gym else { return true }
            return gym.persistentModelID == activeGym?.persistentModelID
        }
    }

    /// Entries of finished sessions with at least one completed set, newest first.
    static func finishedEntries(for exercise: Exercise, excluding excluded: WorkoutSession? = nil) -> [SessionExercise] {
        exercise.sessionEntries
            .filter { entry in
                guard let session = entry.session, session.endDate != nil else { return false }
                if let excluded, session.persistentModelID == excluded.persistentModelID { return false }
                return entry.sets.contains(where: \.isCompleted)
            }
            .sorted { ($0.session?.startDate ?? .distantPast) > ($1.session?.startDate ?? .distantPast) }
    }

    static func lastPerformance(of exercise: Exercise, excluding session: WorkoutSession? = nil) -> SessionExercise? {
        finishedEntries(for: exercise, excluding: session).first
    }

    static func bestOneRepMax(of entry: SessionExercise) -> Double {
        entry.workingSets.map { estimatedOneRepMax(weight: $0.weight, reps: $0.reps) }.max() ?? 0
    }

    static func progress(for exercise: Exercise) -> [ProgressPoint] {
        finishedEntries(for: exercise)
            .compactMap { entry -> ProgressPoint? in
                let sets = entry.workingSets
                guard let date = entry.session?.startDate, !sets.isEmpty else { return nil }
                return ProgressPoint(
                    id: entry.persistentModelID,
                    date: date,
                    topWeight: sets.map(\.weight).max() ?? 0,
                    estimatedOneRepMax: bestOneRepMax(of: entry)
                )
            }
            .sorted { $0.date < $1.date }
    }

    /// True if this entry beats every earlier finished session of the same exercise.
    static func isPersonalRecord(_ entry: SessionExercise) -> Bool {
        guard let exercise = entry.exercise, let session = entry.session else { return false }
        let current = bestOneRepMax(of: entry)
        let previous = finishedEntries(for: exercise, excluding: session)
            .filter { ($0.session?.startDate ?? .distantFuture) < session.startDate }
        guard current > 0, !previous.isEmpty else { return false }
        return current > (previous.map { bestOneRepMax(of: $0) }.max() ?? 0)
    }

    /// Display numbers for a set list: normal sets count 1, 2, 3 …; other kinds show a badge instead.
    static func setNumbers(_ sets: [SetEntry]) -> [Int] {
        var counter = 0
        return sets.map { set in
            if set.kind == .normal { counter += 1 }
            return counter
        }
    }

    /// "3 × 8 @ 80 kg" when all working sets are equal, otherwise "80 kg × 8 · 75 kg × 8".
    /// Warm-ups are left out and mentioned as "+ 2 Aufwärmsätze".
    static func summary(of entry: SessionExercise) -> String {
        let completed = entry.sortedSets.filter(\.isCompleted)
        let sets = completed.filter(\.kind.countsAsWorkingSet)
        let warmups = completed.count - sets.count
        let warmupText = Format.count(warmups, "Aufwärmsatz", "Aufwärmsätze")
        guard let first = sets.first else { return warmups > 0 ? warmupText : "–" }

        let main: String
        if sets.allSatisfy({ $0.weight == first.weight && $0.reps == first.reps }) {
            main = first.weight > 0
                ? "\(sets.count) × \(first.reps) @ \(Format.weight(first.weight)) kg"
                : "\(sets.count) × \(first.reps) Wdh."
        } else {
            main = sets
                .map { $0.weight > 0 ? "\(Format.weight($0.weight)) kg × \($0.reps)" : "\($0.reps) Wdh." }
                .joined(separator: " · ")
        }
        return warmups > 0 ? "\(main) + \(warmupText)" : main
    }
}
