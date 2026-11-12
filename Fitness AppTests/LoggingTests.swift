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
}
