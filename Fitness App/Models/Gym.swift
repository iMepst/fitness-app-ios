import Foundation
import SwiftData

/// A gym (studio). Machines are bound to a gym because machine weights
/// are not comparable between gyms.
@Model
final class Gym {
    var id: UUID
    var name: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Exercise.gym)
    var exercises: [Exercise] = []

    @Relationship(deleteRule: .nullify, inverse: \WorkoutSession.gym)
    var sessions: [WorkoutSession] = []

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = .now
    }
}

extension Array where Element == Gym {
    /// The gym matching the stored active ID, falling back to the first gym.
    func active(id: String) -> Gym? {
        first { $0.id.uuidString == id } ?? first
    }
}
