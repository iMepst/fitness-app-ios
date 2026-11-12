import Foundation
import HealthKit
import SwiftData

/// Thin wrapper around HealthKit: strength workouts (write) and body mass (read/write).
@MainActor
final class HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()
    private let bodyMass = HKQuantityType(.bodyMass)
    private let kilogram = HKUnit.gramUnit(with: .kilo)

    enum HealthError: LocalizedError {
        case unavailable
        case workoutNotFinished
        case nothingSaved

        var errorDescription: String? {
            switch self {
            case .unavailable: "Apple Health ist auf diesem Gerät nicht verfügbar."
            case .workoutNotFinished: "Das Training ist noch nicht beendet."
            case .nothingSaved: "Apple Health hat das Training nicht gespeichert."
            }
        }
    }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async throws {
        guard isAvailable else { throw HealthError.unavailable }
        try await store.requestAuthorization(
            toShare: [HKObjectType.workoutType(), bodyMass],
            read: [bodyMass, HKObjectType.workoutType()]
        )
    }

    /// Saves a finished session as "Traditional Strength Training" and returns the workout's UUID.
    func saveWorkout(_ session: WorkoutSession) async throws -> UUID {
        guard isAvailable else { throw HealthError.unavailable }
        guard let end = session.endDate else { throw HealthError.workoutNotFinished }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor

        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        try await builder.beginCollection(at: session.startDate)
        try await builder.endCollection(at: end)

        var metadata: [String: Any] = [HKMetadataKeyIndoorWorkout: true, "Training": session.displayTitle]
        if !session.gymName.isEmpty { metadata["Studio"] = session.gymName }
        metadata["Sätze"] = session.workingSets.count
        metadata["Volumen (kg)"] = Int(session.volume.rounded())
        try await builder.addMetadata(metadata)

        guard let workout = try await builder.finishWorkout() else { throw HealthError.nothingSaved }
        return workout.uuid
    }

    func deleteWorkout(id: UUID) async throws {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(HKQuery.predicateForObject(with: id))],
            sortDescriptors: []
        )
        let workouts = try await descriptor.result(for: store)
        if !workouts.isEmpty { try await store.delete(workouts) }
    }

    func bodyWeightSamples(since start: Date) async throws -> [BodyWeightSync.Sample] {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: bodyMass, predicate: HKQuery.predicateForSamples(withStart: start, end: nil))],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return try await descriptor.result(for: store).map {
            BodyWeightSync.Sample(id: $0.uuid, date: $0.startDate, kg: $0.quantity.doubleValue(for: kilogram))
        }
    }

    func saveBodyWeight(kg: Double, date: Date) async throws -> UUID {
        let sample = HKQuantitySample(
            type: bodyMass,
            quantity: HKQuantity(unit: kilogram, doubleValue: kg),
            start: date,
            end: date
        )
        try await store.save(sample)
        return sample.uuid
    }

    /// Only works for samples this app wrote; throws for samples from other apps.
    func deleteBodyWeight(id: UUID) async throws {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: bodyMass, predicate: HKQuery.predicateForObject(with: id))],
            sortDescriptors: []
        )
        let samples = try await descriptor.result(for: store)
        if !samples.isEmpty { try await store.delete(samples) }
    }
}

/// Pure merge rules for body weight imports (no HealthKit, unit-testable).
enum BodyWeightSync {
    struct Sample: Equatable {
        let id: UUID
        let date: Date
        let kg: Double
    }

    /// UUIDs the user deleted in the app but that belong to another app in Health – never re-import them.
    static let ignoredKey = "healthIgnoredBodyWeightIDs"

    static var ignoredIDs: Set<UUID> {
        get { Set((UserDefaults.standard.stringArray(forKey: ignoredKey) ?? []).compactMap(UUID.init(uuidString:))) }
        set { UserDefaults.standard.set(newValue.map(\.uuidString), forKey: ignoredKey) }
    }

    /// Inserts samples whose UUID is neither known locally nor ignored. Returns how many were added.
    @discardableResult
    static func merge(_ samples: [Sample], existing: [BodyWeightEntry], ignored: Set<UUID>, into context: ModelContext) -> Int {
        var known = Set(existing.compactMap(\.healthKitUUID)).union(ignored)
        var added = 0
        for sample in samples where sample.kg > 0 && !known.contains(sample.id) {
            context.insert(BodyWeightEntry(date: sample.date, kg: sample.kg, healthKitUUID: sample.id))
            known.insert(sample.id)
            added += 1
        }
        return added
    }
}

/// App-level sync: checks the setting and keeps SwiftData and Health in step. Errors are
/// swallowed on purpose – Health is optional and must never block logging a workout.
@MainActor
enum HealthSync {
    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: AppSettings.healthSyncKey) && HealthKitService.shared.isAvailable
    }

    static func export(_ session: WorkoutSession, in context: ModelContext) async {
        guard isEnabled, session.healthKitWorkoutID == nil, session.endDate != nil else { return }
        guard let id = try? await HealthKitService.shared.saveWorkout(session) else { return }
        session.healthKitWorkoutID = id
        try? context.save()
    }

    /// Exports finished sessions that are not in Health yet. Returns the number exported.
    static func exportPending(in context: ModelContext) async -> Int {
        guard isEnabled else { return 0 }
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.endDate != nil && $0.healthKitWorkoutID == nil },
            sortBy: [SortDescriptor(\.startDate)]
        )
        var exported = 0
        for session in (try? context.fetch(descriptor)) ?? [] {
            await export(session, in: context)
            if session.healthKitWorkoutID != nil { exported += 1 }
        }
        return exported
    }

    static func deleteWorkout(id: UUID?) {
        guard isEnabled, let id else { return }
        Task { try? await HealthKitService.shared.deleteWorkout(id: id) }
    }

    static func importBodyWeights(in context: ModelContext) async {
        guard isEnabled else { return }
        let start = Calendar.current.date(byAdding: .day, value: -365, to: .now) ?? .distantPast
        guard let samples = try? await HealthKitService.shared.bodyWeightSamples(since: start) else { return }
        let existing = (try? context.fetch(FetchDescriptor<BodyWeightEntry>())) ?? []
        if BodyWeightSync.merge(samples, existing: existing, ignored: BodyWeightSync.ignoredIDs, into: context) > 0 {
            try? context.save()
        }
    }

    static func exportBodyWeight(_ entry: BodyWeightEntry, in context: ModelContext) async {
        guard isEnabled, entry.healthKitUUID == nil else { return }
        guard let id = try? await HealthKitService.shared.saveBodyWeight(kg: entry.kg, date: entry.date) else { return }
        entry.healthKitUUID = id
        try? context.save()
    }

    /// Remembers the sample as ignored (so it is never re-imported) and deletes it from Health
    /// when it is ours – samples from other apps (e.g. a scale) can't be deleted and stay there.
    static func deleteBodyWeight(id: UUID?) {
        guard let id else { return }
        BodyWeightSync.ignoredIDs.insert(id)
        guard isEnabled else { return }
        Task { try? await HealthKitService.shared.deleteBodyWeight(id: id) }
    }
}
