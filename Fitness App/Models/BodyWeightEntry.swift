import Foundation
import SwiftData

@Model
final class BodyWeightEntry {
    var date: Date = Date.now
    /// Kilograms.
    var kg: Double = 0
    /// Set when the entry came from (or was written to) Apple Health – prevents duplicate imports.
    var healthKitUUID: UUID?

    init(date: Date = .now, kg: Double, healthKitUUID: UUID? = nil) {
        self.date = date
        self.kg = kg
        self.healthKitUUID = healthKitUUID
    }
}
