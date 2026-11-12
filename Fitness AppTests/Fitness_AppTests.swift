//
//  Fitness_AppTests.swift
//  Fitness AppTests
//
//  Created by Markus Epstein on 12.11.26.
//

import Testing
import Foundation
import SwiftData
@testable import Fitness_App

@MainActor
struct WorkoutStatsTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: Schema(AppSchema.models),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
    }

    @Test func estimatedOneRepMax() {
        #expect(WorkoutStats.estimatedOneRepMax(weight: 100, reps: 1) == 100)
        #expect(abs(WorkoutStats.estimatedOneRepMax(weight: 100, reps: 10) - 133.333) < 0.01)
        #expect(WorkoutStats.estimatedOneRepMax(weight: 100, reps: 0) == 0)
    }

    @Test func seedingIsIdempotent() throws {
        let gym = SeedData.seedIfNeeded(context: context)
        #expect(gym?.name == SeedData.defaultGymName)
        let count = try context.fetchCount(FetchDescriptor<Exercise>())
        #expect(count == SeedData.universalExercises.count)

        #expect(SeedData.seedIfNeeded(context: context) == nil)
        #expect(try context.fetchCount(FetchDescriptor<Exercise>()) == count)
        #expect(try context.fetchCount(FetchDescriptor<Gym>()) == 1)
    }

    @Test func availableExercisesAreUniversalPlusActiveGym() {
        let gymA = Gym(name: "A")
        let gymB = Gym(name: "B")
        context.insert(gymA)
        context.insert(gymB)
        let bench = Exercise(name: "Bankdrücken", muscleGroup: .brust, equipment: .langhantel)
        let pressA = Exercise(name: "Brustpresse A", muscleGroup: .brust, equipment: .maschine)
        let pressB = Exercise(name: "Brustpresse B", muscleGroup: .brust, equipment: .maschine)
        [bench, pressA, pressB].forEach(context.insert)
        pressA.gym = gymA
        pressB.gym = gymB

        let names = Set(WorkoutStats.available([bench, pressA, pressB], activeGym: gymA).map(\.name))
        #expect(names == ["Bankdrücken", "Brustpresse A"])
    }

    @Test func newSessionIsPrefilledFromLastFinishedSession() {
        let bench = Exercise(name: "Bankdrücken", muscleGroup: .brust, equipment: .langhantel)
        context.insert(bench)

        let old = WorkoutFactory.startSession(plan: nil, gym: nil, in: context)
        let oldEntry = WorkoutFactory.addExercise(bench, to: old, targetSets: 2, in: context)
        for set in oldEntry.sets {
            set.weight = 80
            set.reps = 8
            set.isCompleted = true
        }
        #expect(WorkoutFactory.finish(old, in: context))

        let current = WorkoutFactory.startSession(plan: nil, gym: nil, in: context)
        let entry = WorkoutFactory.addExercise(bench, to: current, in: context)
        #expect(entry.sets.count == 2)
        #expect(entry.sets.allSatisfy { $0.weight == 80 && $0.reps == 8 })

        let last = WorkoutStats.lastPerformance(of: bench, excluding: current)
        #expect(last?.session?.persistentModelID == old.persistentModelID)
        #expect(WorkoutStats.summary(of: oldEntry) == "2 × 8 @ 80 kg")
    }

    @Test func finishDropsOpenSetsAndRejectsEmptyWorkouts() {
        let squat = Exercise(name: "Kniebeuge", muscleGroup: .beine, equipment: .langhantel)
        let curl = Exercise(name: "Hammercurls", muscleGroup: .bizeps, equipment: .kurzhantel)
        context.insert(squat)
        context.insert(curl)

        let session = WorkoutFactory.startSession(plan: nil, gym: nil, in: context)
        let squatEntry = WorkoutFactory.addExercise(squat, to: session, targetSets: 3, in: context)
        WorkoutFactory.addExercise(curl, to: session, targetSets: 2, in: context)

        #expect(!WorkoutFactory.finish(session, in: context))
        #expect(session.endDate == nil)

        squatEntry.sortedSets[0].weight = 100
        squatEntry.sortedSets[0].isCompleted = true
        #expect(WorkoutFactory.finish(session, in: context))
        #expect(session.endDate != nil)
        #expect(session.exercises.count == 1)
        #expect(session.completedSets.count == 1)
        #expect(session.volume == 1000)
    }
}
