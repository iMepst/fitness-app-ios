import Foundation
import SwiftData
import CoreLocation

/// A gym (studio). Machines are bound to a gym because machine weights
/// are not comparable between gyms.
@Model
final class Gym {
    var id: UUID
    var name: String
    var createdAt: Date

    // MARK: Studio info (all defaulted for lightweight migration)

    var address: String = ""
    var latitude: Double?
    var longitude: Double?
    var phone: String = ""
    var websiteURL: String = ""
    /// Apple Maps place identifier, used to reopen the Apple place card.
    var mapItemID: String?

    /// JSON-encoded `MembershipContract`.
    var contractData: Data?

    /// Locker used on the current visit; expires after `lockerLifetime`.
    var lockerNumber: String?
    var lockerSetAt: Date?

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

extension Gym {
    static let lockerLifetime: TimeInterval = 12 * 3600

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var hasLocation: Bool { coordinate != nil }

    var contract: MembershipContract? {
        get { contractData.flatMap { try? JSONDecoder().decode(MembershipContract.self, from: $0) } }
        set { contractData = newValue.flatMap { try? JSONEncoder().encode($0) } }
    }

    /// The locker number of the current visit, or nil once it has expired.
    func currentLocker(now: Date = .now) -> String? {
        guard let lockerNumber, !lockerNumber.isEmpty, let lockerSetAt,
              now.timeIntervalSince(lockerSetAt) < Self.lockerLifetime else { return nil }
        return lockerNumber
    }

    func setLocker(_ number: String?, now: Date = .now) {
        let trimmed = number?.trimmingCharacters(in: .whitespaces) ?? ""
        lockerNumber = trimmed.isEmpty ? nil : trimmed
        lockerSetAt = trimmed.isEmpty ? nil : now
    }
}

extension Array where Element == Gym {
    /// The gym matching the stored active ID, falling back to the first gym.
    func active(id: String) -> Gym? {
        first { $0.id.uuidString == id } ?? first
    }
}
