import Testing
import Foundation
import SwiftData
@testable import Fitness_App

@MainActor
struct StatsTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    /// Monday-based calendar in a fixed time zone so results don't depend on the machine.
    let calendar: Calendar = {
        var calendar = TrainingStats.calendar
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    init() throws {
        container = try ModelContainer(
            for: Schema(AppSchema.models),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
    }

    /// 2026-11-12 is a Thursday.
    private func date(_ day: Int, month: Int = 11, hour: Int = 18) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    @discardableResult
    private func workout(
        on date: Date,
        _ exercise: Exercise,
        sets: [(Double, Int, SetKind)] = [(50, 10, .normal)],
        targetReps: ClosedRange<Int>? = nil
    ) -> SessionExercise {
        let session = WorkoutSession(startDate: date, plan: nil, gym: nil)
        context.insert(session)
        let entry = WorkoutFactory.addExercise(exercise, to: session, targetSets: sets.count, targetReps: targetReps, in: context)
        for (set, values) in zip(entry.sortedSets, sets) {
            set.weight = values.0
            set.reps = values.1
            set.kind = values.2
            set.isCompleted = true
        }
        WorkoutFactory.finish(session, in: context)
        session.endDate = date.addingTimeInterval(3600)
        return entry
    }

    private func exercise(_ name: String, _ muscle: MuscleGroup = .brust, _ equipment: Equipment = .langhantel) -> Exercise {
        let exercise = Exercise(name: name, muscleGroup: muscle, equipment: equipment)
        context.insert(exercise)
        return exercise
    }

    private var allSessions: [WorkoutSession] {
        (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
    }

    // MARK: - Weeks & streak

    @Test func weeksStartOnMonday() {
        let start = TrainingStats.weekStart(of: date(12), calendar: calendar)
        #expect(start == calendar.date(from: DateComponents(year: 2026, month: 11, day: 9))!)
    }

    @Test func streakCountsConsecutiveWeeksMeetingGoal() {
        let bench = exercise("Bankdrücken")
        // Weeks of Oct 26, Nov 2: two workouts each; week of Oct 19: only one (breaks).
        for day in [27, 29] { workout(on: date(day, month: 10), bench) }
        for day in [3, 5] { workout(on: date(day), bench) }
        workout(on: date(20, month: 10), bench)

        // Current week (Nov 9) has one workout – not reached yet, doesn't break the streak.
        workout(on: date(10), bench)
        #expect(TrainingStats.streak(allSessions, goal: 2, now: date(12), calendar: calendar) == 2)

        // Reaching the goal this week extends it.
        workout(on: date(11), bench)
        #expect(TrainingStats.streak(allSessions, goal: 2, now: date(12), calendar: calendar) == 3)
    }

    @Test func streakIsZeroAfterAMissedWeek() {
        let bench = exercise("Bankdrücken")
        workout(on: date(27, month: 10), bench)
        #expect(TrainingStats.streak(allSessions, goal: 1, now: date(12), calendar: calendar) == 0)
    }

    @Test func trainingDaysAndWeeklyVolume() {
        let bench = exercise("Bankdrücken")
        workout(on: date(10, hour: 8), bench, sets: [(100, 5, .normal)])
        workout(on: date(10, hour: 19), bench, sets: [(100, 5, .normal), (40, 10, .aufwaermen)])
        workout(on: date(3), bench, sets: [(80, 10, .normal)])

        let days = TrainingStats.trainingDays(allSessions, weeks: 4, now: date(12), calendar: calendar)
        #expect(days[calendar.startOfDay(for: date(10))] == 2)
        #expect(days[calendar.startOfDay(for: date(3))] == 1)
        #expect(days.count == 2)

        let volume = TrainingStats.weeklyVolume(allSessions, weeks: 3, now: date(12), calendar: calendar)
        #expect(volume.map(\.volume) == [0, 800, 1000])
    }

    @Test func setsPerMuscleCountsWorkingSetsOnly() {
        let bench = exercise("Bankdrücken", .brust)
        let squat = exercise("Kniebeuge", .beine)
        workout(on: date(10), bench, sets: [(40, 10, .aufwaermen), (80, 8, .normal), (80, 8, .normal)])
        workout(on: date(11), squat, sets: [(100, 5, .normal)])
        workout(on: date(4), bench, sets: [(80, 8, .normal)])

        let counts = TrainingStats.setsPerMuscle(allSessions, inWeekOf: date(12), calendar: calendar)
        #expect(counts == [.brust: 2, .beine: 1])

        let rows = TrainingStats.muscleComparison(allSessions, now: date(12), calendar: calendar)
        #expect(rows.filter { $0.muscle == .brust }.map(\.sets) == [1, 2])
        #expect(rows.filter { $0.muscle == .beine }.map(\.sets) == [0, 1])
    }

    // MARK: - Records & suggestions

    @Test func recordsTrackBestValuesWithDates() {
        let bench = exercise("Bankdrücken")
        workout(on: date(3), bench, sets: [(100, 5, .normal), (60, 15, .normal)])
        workout(on: date(10), bench, sets: [(105, 3, .normal), (140, 1, .aufwaermen)])

        let records = WorkoutStats.records(for: bench)
        #expect(records.heaviestWeight == RecordValue(value: 105, date: date(10)))
        #expect(records.mostReps == RecordValue(value: 15, date: date(3)))
        #expect(records.bestSetVolume == RecordValue(value: 900, date: date(3)))
        #expect(records.bestSessionVolume == RecordValue(value: 1400, date: date(3)))
        #expect(abs((records.bestOneRepMax?.value ?? 0) - 116.667) < 0.01)
    }

    @Test func recordSetNeedsHistoryAndMustBeatSession() throws {
        let bench = exercise("Bankdrücken")
        workout(on: date(3), bench, sets: [(100, 5, .normal)])

        let current = WorkoutFactory.startSession(plan: nil, gym: nil, in: context)
        let entry = WorkoutFactory.addExercise(bench, to: current, targetSets: 3, in: context)
        let sets = entry.sortedSets
        sets[0].weight = 100; sets[0].reps = 6; sets[0].isCompleted = true
        #expect(WorkoutStats.isRecordSet(sets[0]))

        sets[1].weight = 100; sets[1].reps = 6; sets[1].isCompleted = true
        #expect(!WorkoutStats.isRecordSet(sets[1]), "equal to the set just done – no second banner")

        sets[2].weight = 120; sets[2].reps = 1; sets[2].kind = .aufwaermen; sets[2].isCompleted = true
        #expect(!WorkoutStats.isRecordSet(sets[2]), "warm-ups never count")

        let squat = exercise("Kniebeuge", .beine)
        let first = WorkoutFactory.addExercise(squat, to: current, targetSets: 1, in: context)
        let firstSet = try #require(first.sets.first)
        firstSet.weight = 100; firstSet.reps = 5; firstSet.isCompleted = true
        #expect(!WorkoutStats.isRecordSet(firstSet), "first time doing an exercise is not a record")
    }

    @Test func suggestionWhenTopOfRepRangeWasReached() {
        let bench = exercise("Bankdrücken", .brust, .langhantel)
        workout(on: date(3), bench, sets: [(40, 10, .aufwaermen), (80, 12, .normal), (80, 12, .normal)])

        let current = WorkoutFactory.startSession(plan: nil, gym: nil, in: context)
        let entry = WorkoutFactory.addExercise(bench, to: current, targetReps: 8...12, in: context)
        #expect(WorkoutStats.suggestedWeight(for: entry) == 82.5)

        let noTarget = WorkoutFactory.addExercise(bench, to: current, in: context)
        #expect(WorkoutStats.suggestedWeight(for: noTarget) == nil)
    }

    @Test func noSuggestionWhenRepsWereMissedOrBodyweight() {
        let curl = exercise("Curls", .bizeps, .kurzhantel)
        workout(on: date(3), curl, sets: [(14, 12, .normal), (14, 10, .normal)])
        let dips = exercise("Dips", .trizeps, .koerpergewicht)
        workout(on: date(3), dips, sets: [(10, 12, .normal)])

        let current = WorkoutFactory.startSession(plan: nil, gym: nil, in: context)
        let curlEntry = WorkoutFactory.addExercise(curl, to: current, targetReps: 8...12, in: context)
        let dipsEntry = WorkoutFactory.addExercise(dips, to: current, targetReps: 8...12, in: context)
        #expect(WorkoutStats.suggestedWeight(for: curlEntry) == nil)
        #expect(WorkoutStats.suggestedWeight(for: dipsEntry) == nil)
    }

    @Test func recentRecordsAreNewestFirst() {
        let bench = exercise("Bankdrücken")
        workout(on: date(1), bench, sets: [(80, 5, .normal)])
        workout(on: date(3), bench, sets: [(85, 5, .normal)])
        workout(on: date(5), bench, sets: [(80, 5, .normal)])
        workout(on: date(10), bench, sets: [(90, 5, .normal)])

        let dates = TrainingStats.recentRecords(allSessions, limit: 5).compactMap(\.session?.startDate)
        #expect(dates == [date(10), date(3)])
    }
}
