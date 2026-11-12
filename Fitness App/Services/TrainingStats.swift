import Foundation

struct WeeklyVolume: Identifiable, Equatable {
    var id: Date { weekStart }
    let weekStart: Date
    let volume: Double
}

struct MuscleSetCount: Identifiable, Equatable {
    var id: String { "\(week)-\(muscle.rawValue)" }
    let muscle: MuscleGroup
    let week: String
    let sets: Int
}

/// Pure calculations for the Statistik tab. All functions take the calendar explicitly
/// so tests can use a fixed time zone; weeks start on Monday like the opening hours.
enum TrainingStats {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "de_DE")
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    static func finished(_ sessions: [WorkoutSession]) -> [WorkoutSession] {
        sessions.filter { $0.endDate != nil }
    }

    static func weekStart(of date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    static func sessions(_ sessions: [WorkoutSession], inWeekOf date: Date, calendar: Calendar) -> [WorkoutSession] {
        let start = weekStart(of: date, calendar: calendar)
        return finished(sessions).filter { weekStart(of: $0.startDate, calendar: calendar) == start }
    }

    /// Consecutive weeks that reached the goal. The current week only counts once it is reached,
    /// but an unfinished current week never breaks the streak.
    static func streak(_ sessions: [WorkoutSession], goal: Int, now: Date, calendar: Calendar) -> Int {
        let counts = Dictionary(grouping: finished(sessions)) { weekStart(of: $0.startDate, calendar: calendar) }
            .mapValues(\.count)
        var week = weekStart(of: now, calendar: calendar)
        var streak = 0
        if (counts[week] ?? 0) >= goal { streak += 1 }
        while true {
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: week) else { break }
            week = previous
            guard (counts[week] ?? 0) >= goal else { break }
            streak += 1
        }
        return streak
    }

    /// Workouts per day (start of day) for the last `weeks` weeks including the current one.
    static func trainingDays(_ sessions: [WorkoutSession], weeks: Int, now: Date, calendar: Calendar) -> [Date: Int] {
        guard let first = calendar.date(byAdding: .weekOfYear, value: -(weeks - 1), to: weekStart(of: now, calendar: calendar))
        else { return [:] }
        return Dictionary(
            grouping: finished(sessions).filter { $0.startDate >= first && $0.startDate <= now },
            by: { calendar.startOfDay(for: $0.startDate) }
        ).mapValues(\.count)
    }

    /// Monday of each of the last `weeks` weeks, oldest first.
    static func weekStarts(count weeks: Int, now: Date, calendar: Calendar) -> [Date] {
        let current = weekStart(of: now, calendar: calendar)
        return (0..<weeks).reversed().compactMap { calendar.date(byAdding: .weekOfYear, value: -$0, to: current) }
    }

    static func weeklyVolume(_ sessions: [WorkoutSession], weeks: Int, now: Date, calendar: Calendar) -> [WeeklyVolume] {
        let byWeek = Dictionary(grouping: finished(sessions)) { weekStart(of: $0.startDate, calendar: calendar) }
        return weekStarts(count: weeks, now: now, calendar: calendar).map { start in
            WeeklyVolume(weekStart: start, volume: (byWeek[start] ?? []).reduce(0) { $0 + $1.volume })
        }
    }

    /// Working sets per muscle group in the week containing `date`.
    static func setsPerMuscle(_ sessions: [WorkoutSession], inWeekOf date: Date, calendar: Calendar) -> [MuscleGroup: Int] {
        var counts: [MuscleGroup: Int] = [:]
        for session in self.sessions(sessions, inWeekOf: date, calendar: calendar) {
            for entry in session.exercises {
                guard let muscle = entry.exercise?.muscleGroup else { continue }
                counts[muscle, default: 0] += entry.workingSets.count
            }
        }
        return counts.filter { $0.value > 0 }
    }

    /// Chart rows for this week vs. last week, in muscle group order.
    static func muscleComparison(_ sessions: [WorkoutSession], now: Date, calendar: Calendar) -> [MuscleSetCount] {
        let lastWeekDate = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
        let current = setsPerMuscle(sessions, inWeekOf: now, calendar: calendar)
        let previous = setsPerMuscle(sessions, inWeekOf: lastWeekDate, calendar: calendar)
        return MuscleGroup.allCases.flatMap { muscle -> [MuscleSetCount] in
            guard current[muscle] != nil || previous[muscle] != nil else { return [] }
            return [
                MuscleSetCount(muscle: muscle, week: "Letzte Woche", sets: previous[muscle] ?? 0),
                MuscleSetCount(muscle: muscle, week: "Diese Woche", sets: current[muscle] ?? 0),
            ]
        }
    }

    /// Exercise entries that set a new best estimated 1RM, newest first.
    static func recentRecords(_ sessions: [WorkoutSession], limit: Int) -> [SessionExercise] {
        finished(sessions)
            .sorted { $0.startDate > $1.startDate }
            .lazy
            .flatMap { $0.sortedExercises }
            .filter(WorkoutStats.isPersonalRecord)
            .prefix(limit)
            .map { $0 }
    }
}
