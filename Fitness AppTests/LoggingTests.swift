import Testing
import Foundation
import SwiftData
@testable import Fitness_App

@MainActor
struct LoggingTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: Schema(AppSchema.models),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
    }

    /// Finished session with one exercise and the given (weight, reps, kind) sets.
    @discardableResult
    private func finishedSession(
        _ exercise: Exercise,
        sets: [(Double, Int, SetKind)],
        start: Date = .now.addingTimeInterval(-3600)
    ) -> SessionExercise {
        let session = WorkoutSession(startDate: start, plan: nil, gym: nil)
        context.insert(session)
        let entry = WorkoutFactory.addExercise(exercise, to: session, targetSets: sets.count, in: context)
        for (set, values) in zip(entry.sortedSets, sets) {
            set.weight = values.0
            set.reps = values.1
            set.kind = values.2
            set.isCompleted = true
        }
        WorkoutFactory.finish(session, in: context)
        return entry
    }

    @Test func warmupsAreExcludedFromVolumeAndOneRepMax() {
        let squat = Exercise(name: "Kniebeuge", muscleGroup: .beine, equipment: .langhantel)
        context.insert(squat)
        let entry = finishedSession(squat, sets: [(60, 10, .aufwaermen), (100, 5, .normal), (100, 5, .normal)])

        #expect(WorkoutStats.volume(of: entry.sets) == 1000)
        #expect(entry.session?.volume == 1000)
        #expect(entry.workingSets.count == 2)
        #expect(abs(WorkoutStats.bestOneRepMax(of: entry) - 116.667) < 0.01)
        #expect(WorkoutStats.summary(of: entry) == "2 × 5 @ 100 kg + 1 Aufwärmsatz")
    }

    @Test func previousSetsComeFromLastFinishedSessionInOrder() {
        let bench = Exercise(name: "Bankdrücken", muscleGroup: .brust, equipment: .langhantel)
        context.insert(bench)
        finishedSession(bench, sets: [(50, 10, .normal)], start: .now.addingTimeInterval(-7200))
        finishedSession(bench, sets: [(40, 12, .aufwaermen), (60, 8, .normal), (62.5, 6, .normal)])

        let running = WorkoutSession(plan: nil, gym: nil)
        context.insert(running)
        let entry = WorkoutFactory.addExercise(bench, to: running, targetSets: 3, in: context)
        entry.sortedSets[0].isCompleted = true  // the running session itself is ignored

        let previous = WorkoutStats.previousSets(for: entry)
        #expect(previous.map(\.weight) == [40, 60, 62.5])
        #expect(previous.map(\.reps) == [12, 8, 6])
    }

    @Test func currentExerciseIsFirstWithOpenSets() {
        let session = session(with: ["A", "B"])
        let e = session.sortedExercises
        #expect(WorkoutStats.currentExercise(in: session) === e[0])

        e[0].sets.forEach { $0.isCompleted = true }
        #expect(WorkoutStats.currentExercise(in: session) === e[1])

        e[1].sets.forEach { $0.isCompleted = true }
        #expect(WorkoutStats.currentExercise(in: session) == nil)
    }

    @Test func onlyWarmupsDoNotCountAsRecord() {
        let bench = Exercise(name: "Bankdrücken", muscleGroup: .brust, equipment: .langhantel)
        context.insert(bench)
        finishedSession(bench, sets: [(80, 8, .normal)], start: .now.addingTimeInterval(-7200))
        let heavyWarmup = finishedSession(bench, sets: [(100, 8, .aufwaermen)])

        #expect(WorkoutStats.bestOneRepMax(of: heavyWarmup) == 0)
        #expect(!WorkoutStats.isPersonalRecord(heavyWarmup))
        #expect(WorkoutStats.summary(of: heavyWarmup) == "1 Aufwärmsatz")
    }

    @Test func setKindsArePrefilledFromLastSession() {
        let row = Exercise(name: "Rudern", muscleGroup: .ruecken, equipment: .langhantel)
        context.insert(row)
        finishedSession(row, sets: [(40, 10, .aufwaermen), (70, 8, .normal), (50, 12, .drop)])

        let current = WorkoutFactory.startSession(plan: nil, gym: nil, in: context)
        let entry = WorkoutFactory.addExercise(row, to: current, in: context)
        #expect(entry.sortedSets.map(\.kind) == [.aufwaermen, .normal, .drop])

        WorkoutFactory.addSet(to: entry, in: context)
        #expect(entry.sortedSets.last?.kind == .drop)
    }

    @Test func planCopiesSupersetAndRepTargets() {
        let curl = Exercise(name: "Curls", muscleGroup: .bizeps, equipment: .kurzhantel)
        context.insert(curl)
        let plan = WorkoutPlan(name: "Arme", sortIndex: 0)
        context.insert(plan)
        let planEntry = PlanEntry(sortIndex: 0, targetSets: 3, repsMin: 8, repsMax: 12)
        context.insert(planEntry)
        planEntry.exercise = curl
        planEntry.supersetGroup = 1
        plan.entries.append(planEntry)

        let session = WorkoutFactory.startSession(plan: plan, gym: nil, in: context)
        let entry = try! #require(session.exercises.first)
        #expect(entry.supersetGroup == 1)
        #expect(entry.targetRepsMin == 8)
        #expect(entry.targetRepsMax == 12)
    }

    @Test func platesRoundTrip() {
        #expect(AppSettings.parsePlates(AppSettings.defaultPlates) == [25, 20, 15, 10, 5, 2.5, 1.25])
        #expect(AppSettings.encodePlates([2.5, 20, 1.25]) == "20.0;2.5;1.25")
        #expect(AppSettings.parsePlates("20.0;20;x;-5") == [20])
    }

    // MARK: - Supersets

    private func session(with names: [String]) -> WorkoutSession {
        let session = WorkoutFactory.startSession(plan: nil, gym: nil, in: context)
        for name in names {
            let exercise = Exercise(name: name, muscleGroup: .ganzkoerper, equipment: .kurzhantel)
            context.insert(exercise)
            WorkoutFactory.addExercise(exercise, to: session, in: context)
        }
        return session
    }

    @Test func linkingFormsSupersetAndRestStartsAfterLastMember() {
        let session = session(with: ["A", "B", "C"])
        let (a, b, c) = (session.sortedExercises[0], session.sortedExercises[1], session.sortedExercises[2])

        Supersets.linkWithNext(a, in: session.exercises)
        #expect(a.supersetGroup != nil && a.supersetGroup == b.supersetGroup)
        #expect(c.supersetGroup == nil)
        #expect(!Supersets.shouldStartRest(after: a, in: session.exercises))
        #expect(Supersets.shouldStartRest(after: b, in: session.exercises))
        #expect(Supersets.shouldStartRest(after: c, in: session.exercises))

        Supersets.linkWithNext(b, in: session.exercises)
        #expect(c.supersetGroup == a.supersetGroup)
        #expect(!Supersets.shouldStartRest(after: b, in: session.exercises))
        #expect(Supersets.shouldStartRest(after: c, in: session.exercises))
        #expect(Supersets.labels(in: session.exercises) == [a.supersetGroup!: "A"])
    }

    @Test func unlinkingAndRemovingDissolveSingleMemberGroups() {
        let session = session(with: ["A", "B", "C", "D"])
        let e = session.sortedExercises
        Supersets.linkWithNext(e[0], in: session.exercises)
        Supersets.linkWithNext(e[2], in: session.exercises)
        #expect(Supersets.labels(in: session.exercises).values.sorted() == ["A", "B"])

        Supersets.unlink(e[0], in: session.exercises)
        #expect(e[0].supersetGroup == nil)
        #expect(e[1].supersetGroup == nil)

        WorkoutFactory.remove(e[3], from: session, in: context)
        #expect(e[2].supersetGroup == nil)
    }

    @Test func linkingMergesNeighbouringGroups() {
        let session = session(with: ["A", "B", "C", "D"])
        let e = session.sortedExercises
        Supersets.linkWithNext(e[0], in: session.exercises)
        Supersets.linkWithNext(e[2], in: session.exercises)
        Supersets.linkWithNext(e[1], in: session.exercises)
        #expect(Set(e.map(\.supersetGroup)).count == 1)
        #expect(Supersets.shouldStartRest(after: e[3], in: session.exercises))
        #expect(!Supersets.shouldStartRest(after: e[2], in: session.exercises))
    }

    @Test func unlinkingFromNextSplitsGroupAfterMember() {
        let session = session(with: ["A", "B", "C", "D"])
        let e = session.sortedExercises
        Supersets.linkWithNext(e[0], in: session.exercises)
        Supersets.linkWithNext(e[1], in: session.exercises)
        Supersets.linkWithNext(e[2], in: session.exercises)

        // A-B-C-D → A-B | C-D
        Supersets.unlinkFromNext(e[1], in: session.exercises)
        #expect(Supersets.isLinkedWithNext(e[0], in: session.exercises))
        #expect(!Supersets.isLinkedWithNext(e[1], in: session.exercises))
        #expect(Supersets.isLinkedWithNext(e[2], in: session.exercises))
        #expect(e[0].supersetGroup != e[2].supersetGroup)

        // A-B | C-D → A-B, C and D single
        Supersets.unlinkFromNext(e[2], in: session.exercises)
        #expect(e[2].supersetGroup == nil)
        #expect(e[3].supersetGroup == nil)
        #expect(e[0].supersetGroup != nil)
    }

    // MARK: - Plates & numbering

    @Test func plateCalculatorLoadsExactWeight() throws {
        let plates = AppSettings.parsePlates(AppSettings.defaultPlates)
        let loading = try #require(PlateCalculator.loading(target: 102.5, bar: 20, plates: plates))
        #expect(loading.perSide == [25, 15, 1.25])
        #expect(loading.remainderPerSide == 0)
        #expect(loading.achieved == 102.5)
    }

    @Test func plateCalculatorReportsRemainder() throws {
        let loading = try #require(PlateCalculator.loading(target: 61, bar: 20, plates: [20, 10, 5, 2.5]))
        #expect(loading.perSide == [20])
        #expect(loading.remainderPerSide == 0.5)
        #expect(loading.achieved == 60)
    }

    @Test func plateCalculatorEdgeCases() throws {
        #expect(PlateCalculator.loading(target: 15, bar: 20, plates: [10]) == nil)
        let barOnly = try #require(PlateCalculator.loading(target: 20, bar: 20, plates: [10]))
        #expect(barOnly.perSide.isEmpty)
        #expect(barOnly.achieved == 20)
    }

    @Test func nearestLoadableWeights() throws {
        let plates: [Double] = [20, 10, 5, 2.5, 1.25]
        let nearest = try #require(PlateCalculator.nearest(target: 101, bar: 20, plates: plates))
        #expect(nearest.lower == 100)
        #expect(nearest.upper == 102.5)
        #expect(PlateCalculator.nearest(target: 102.5, bar: 20, plates: plates) == nil, "exact weights need no alternative")
    }

    @Test func stepJumpsToLoadableWeights() {
        let plates: [Double] = [20, 10, 5, 2.5, 1.25]
        #expect(PlateCalculator.step(from: 78, bar: 20, plates: plates, up: true) == 80)
        #expect(PlateCalculator.step(from: 78, bar: 20, plates: plates, up: false) == 77.5)
        #expect(PlateCalculator.step(from: 80, bar: 20, plates: plates, up: true) == 82.5)
        #expect(PlateCalculator.step(from: 80, bar: 20, plates: plates, up: false) == 77.5)
        #expect(PlateCalculator.step(from: 20, bar: 20, plates: plates, up: false) == 20)
        #expect(PlateCalculator.step(from: 15, bar: 20, plates: plates, up: true) == 20)
    }

    @Test func setNumbersSkipSpecialSets() {
        let kinds: [SetKind] = [.aufwaermen, .aufwaermen, .normal, .normal, .drop, .normal]
        let sets = kinds.enumerated().map { SetEntry(sortIndex: $0.offset, weight: 50, reps: 5, kind: $0.element) }
        sets.forEach(context.insert)
        #expect(WorkoutStats.setNumbers(sets) == [0, 0, 1, 2, 2, 3])
    }

    // MARK: - Live Activity state

    @Test func activityStateFollowsWorkoutProgress() {
        let session = session(with: ["Bankdrücken", "Rudern"])
        let entries = session.sortedExercises
        let timer = RestTimer()

        var state = WorkoutActivityController.state(for: session, rest: timer)
        #expect(state.currentExercise == "Bankdrücken")
        #expect(state.completedSets == 0)
        #expect(state.restEnd == nil && !state.isResting)

        for set in entries[0].sets { set.isCompleted = true }
        entries[1].sortedSets[0].isCompleted = true
        timer.start(seconds: 90)
        state = WorkoutActivityController.state(for: session, rest: timer)
        #expect(state.currentExercise == "Rudern")
        #expect(state.completedSets == entries[0].sets.count + 1)
        #expect(state.isResting)
        timer.stop()

        for set in entries[1].sets { set.isCompleted = true }
        state = WorkoutActivityController.state(for: session, rest: timer)
        #expect(state.currentExercise == "Rudern", "all done – keeps showing the last exercise")
        #expect(!state.isResting)
    }

    // MARK: - Training home

    private func plan(_ name: String, index: Int, lastDone: Date?, exercise: Exercise) -> WorkoutPlan {
        let plan = WorkoutPlan(name: name, sortIndex: index)
        context.insert(plan)
        let entry = PlanEntry(sortIndex: 0)
        context.insert(entry)
        entry.exercise = exercise
        plan.entries.append(entry)
        if let lastDone {
            let session = WorkoutSession(startDate: lastDone, plan: plan, gym: nil)
            context.insert(session)
            session.endDate = lastDone.addingTimeInterval(3600)
        }
        return plan
    }

    @Test func nextPlanIsTheOneDoneLongestAgo() {
        let squat = Exercise(name: "Kniebeuge", muscleGroup: .beine, equipment: .langhantel)
        context.insert(squat)
        let push = plan("Push", index: 0, lastDone: .now.addingTimeInterval(-86_400 * 2), exercise: squat)
        let pull = plan("Pull", index: 1, lastDone: .now.addingTimeInterval(-86_400 * 4), exercise: squat)
        #expect(WorkoutPlan.next(in: [push, pull]) === pull)

        let legs = plan("Beine", index: 2, lastDone: nil, exercise: squat)
        #expect(WorkoutPlan.next(in: [push, pull, legs]) === legs)

        // A single startable plan is never "next" (nothing to choose between).
        let empty = WorkoutPlan(name: "Leer", sortIndex: 3)
        context.insert(empty)
        #expect(WorkoutPlan.next(in: [push, empty]) == nil)
    }

    @Test func daysAgoUsesCalendarDays() {
        let calendar = TrainingStats.calendar
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 9))!
        func ago(_ days: Int) -> Date { calendar.date(byAdding: .day, value: -days, to: now)! }
        #expect(Format.daysAgo(now, now: now, calendar: calendar) == "heute")
        #expect(Format.daysAgo(ago(1), now: now, calendar: calendar) == "gestern")
        #expect(Format.daysAgo(ago(5), now: now, calendar: calendar) == "vor 5 Tagen")
        #expect(Format.daysAgo(ago(21), now: now, calendar: calendar) == "vor 3 Wochen")
    }
}
