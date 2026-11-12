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
}
