import Foundation
import SwiftData

struct RecordValue: Equatable {
    let value: Double
    let date: Date
}

/// All-time bests of one exercise (working sets of finished sessions only).
struct ExerciseRecords: Equatable {
    var bestOneRepMax: RecordValue?
    var heaviestWeight: RecordValue?
    var mostReps: RecordValue?
    var bestSetVolume: RecordValue?
    var bestSessionVolume: RecordValue?

    var isEmpty: Bool { bestOneRepMax == nil && mostReps == nil }
}

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

    /// Completed sets of the last finished session with this exercise, in order
    /// (index-matched with the running sets for the "Vorher" column).
    static func previousSets(for entry: SessionExercise) -> [SetEntry] {
        guard let exercise = entry.exercise,
              let last = lastPerformance(of: exercise, excluding: entry.session)
        else { return [] }
        return last.sortedSets.filter(\.isCompleted)
    }

    /// The exercise the user is on: the first one (in order) that still has an open set.
    static func currentExercise(in session: WorkoutSession) -> SessionExercise? {
        session.sortedExercises.first { $0.sets.contains { !$0.isCompleted } }
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

    /// True if this completed working set's estimated 1RM beats all earlier finished sessions
    /// and every other completed set of the same exercise in the current session.
    /// Requires history, so the very first session of an exercise never triggers it.
    static func isRecordSet(_ set: SetEntry) -> Bool {
        guard set.isCompleted, set.kind.countsAsWorkingSet,
              let entry = set.sessionExercise, let exercise = entry.exercise
        else { return false }
        let value = estimatedOneRepMax(weight: set.weight, reps: set.reps)
        guard value > 0 else { return false }

        let history = finishedEntries(for: exercise, excluding: entry.session)
        guard !history.isEmpty else { return false }
        let historyBest = history.map(bestOneRepMax(of:)).max() ?? 0
        let sessionBest = entry.workingSets
            .filter { $0.persistentModelID != set.persistentModelID }
            .map { estimatedOneRepMax(weight: $0.weight, reps: $0.reps) }
            .max() ?? 0
        return value > max(historyBest, sessionBest)
    }

    /// Suggests more weight when every working set last time reached the top of the rep range.
    static func suggestedWeight(for entry: SessionExercise) -> Double? {
        guard let exercise = entry.exercise,
              let step = exercise.equipment.progressionStep,
              let targetMax = entry.targetRepsMax,
              let last = lastPerformance(of: exercise, excluding: entry.session)
        else { return nil }
        let sets = last.workingSets.filter { $0.kind == .normal }
        guard !sets.isEmpty, sets.allSatisfy({ $0.reps >= targetMax }) else { return nil }
        let top = sets.map(\.weight).max() ?? 0
        guard top > 0 else { return nil }
        return top + step
    }

    static func records(for exercise: Exercise) -> ExerciseRecords {
        var records = ExerciseRecords()
        func update(_ keyPath: WritableKeyPath<ExerciseRecords, RecordValue?>, _ value: Double, _ date: Date) {
            guard value > 0, value > (records[keyPath: keyPath]?.value ?? 0) else { return }
            records[keyPath: keyPath] = RecordValue(value: value, date: date)
        }
        // Oldest first, so ties keep the date they were first reached.
        for entry in finishedEntries(for: exercise).reversed() {
            guard let date = entry.session?.startDate else { continue }
            let sets = entry.workingSets
            for set in sets {
                update(\.bestOneRepMax, estimatedOneRepMax(weight: set.weight, reps: set.reps), date)
                update(\.heaviestWeight, set.weight, date)
                update(\.mostReps, Double(set.reps), date)
                update(\.bestSetVolume, set.weight * Double(set.reps), date)
            }
            update(\.bestSessionVolume, volume(of: sets), date)
        }
        return records
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
