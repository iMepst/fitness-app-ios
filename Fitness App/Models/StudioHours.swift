import Foundation

/// Opening and staffed hours of a studio, built into the app (no editor).
/// MapKit doesn't expose opening hours, so known studios are listed here;
/// changes ship with an app update.
nonisolated struct StudioHours: Hashable {
    var opening: WeeklyHours
    /// When service staff / trainers are usually on site; nil if unknown.
    var staffed: WeeklyHours?
}

nonisolated enum BuiltInStudioHours {
    struct Entry {
        /// Matched against the gym name (case-insensitive, exact).
        let names: [String]
        /// Matched against the address (case-insensitive substring), so a
        /// renamed gym is still recognised by its Apple Maps address.
        let addressKey: String
        let hours: StudioHours
    }

    static let entries: [Entry] = [
        Entry(
            names: ["John Reed Wandsbek", "JOHN REED Fitness"],
            addressKey: "Walddörferstraße 140",
            hours: StudioHours(
                opening: .aroundTheClock,
                staffed: .daily([TimeRange(open: 8 * 60, close: 22 * 60)])
            )
        ),
    ]

    static func hours(name: String, address: String) -> StudioHours? {
        let name = name.trimmingCharacters(in: .whitespaces)
        if let entry = entries.first(where: { $0.names.contains { $0.caseInsensitiveCompare(name) == .orderedSame } }) {
            return entry.hours
        }
        guard !address.isEmpty else { return nil }
        return entries.first { address.localizedCaseInsensitiveContains($0.addressKey) }?.hours
    }
}

extension Gym {
    /// Built-in hours for this studio, if it is a known one.
    var builtInHours: StudioHours? {
        BuiltInStudioHours.hours(name: name, address: address)
    }
}
