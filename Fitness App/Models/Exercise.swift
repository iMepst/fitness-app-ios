import Foundation
import SwiftData

@Model
final class Exercise {
    var name: String
    var muscleGroupRaw: String
    var equipmentRaw: String
    var notes: String
    var isBuiltIn: Bool
    var createdAt: Date

    /// `nil` = universal exercise, available in every gym.
    var gym: Gym?

    @Relationship(deleteRule: .cascade, inverse: \PlanEntry.exercise)
    var planEntries: [PlanEntry] = []

    @Relationship(deleteRule: .nullify, inverse: \SessionExercise.exercise)
    var sessionEntries: [SessionExercise] = []

    init(
        name: String,
        muscleGroup: MuscleGroup,
        equipment: Equipment,
        notes: String = "",
        isBuiltIn: Bool = false,
        gym: Gym? = nil
    ) {
        self.name = name
        self.muscleGroupRaw = muscleGroup.rawValue
        self.equipmentRaw = equipment.rawValue
        self.notes = notes
        self.isBuiltIn = isBuiltIn
        self.createdAt = .now
        self.gym = gym
    }

    var muscleGroup: MuscleGroup {
        get { MuscleGroup(rawValue: muscleGroupRaw) ?? .ganzkoerper }
        set { muscleGroupRaw = newValue.rawValue }
    }

    var equipment: Equipment {
        get { Equipment(rawValue: equipmentRaw) ?? .sonstiges }
        set { equipmentRaw = newValue.rawValue }
    }
}
