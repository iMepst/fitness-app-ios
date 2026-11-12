import Foundation

/// Anything that can be grouped into a superset: plan entries and session exercises.
protocol SupersetMember: AnyObject {
    var sortIndex: Int { get }
    var supersetGroup: Int? { get set }
}

extension SessionExercise: SupersetMember {}
extension PlanEntry: SupersetMember {}

/// Superset grouping rules shared by the plan editor and the active workout.
enum Supersets {
    static func sorted<T: SupersetMember>(_ items: [T]) -> [T] {
        items.sorted { $0.sortIndex < $1.sortIndex }
    }

    static func next<T: SupersetMember>(after member: T, in items: [T]) -> T? {
        let list = sorted(items)
        guard let index = list.firstIndex(where: { $0 === member }), index + 1 < list.count else { return nil }
        return list[index + 1]
    }

    /// Members of the member's group (only itself if it isn't in a group), in order.
    static func group<T: SupersetMember>(of member: T, in items: [T]) -> [T] {
        guard let id = member.supersetGroup else { return [member] }
        return sorted(items).filter { $0.supersetGroup == id }
    }

    static func isInSuperset<T: SupersetMember>(_ member: T, in items: [T]) -> Bool {
        group(of: member, in: items).count > 1
    }

    static func isLinkedWithNext<T: SupersetMember>(_ member: T, in items: [T]) -> Bool {
        guard let id = member.supersetGroup, let next = next(after: member, in: items) else { return false }
        return next.supersetGroup == id
    }

    /// Puts the member and the following item into the same superset (merging groups if needed).
    static func linkWithNext<T: SupersetMember>(_ member: T, in items: [T]) {
        guard let next = next(after: member, in: items) else { return }
        let id = member.supersetGroup ?? next.supersetGroup ?? ((items.compactMap(\.supersetGroup).max() ?? 0) + 1)
        if let old = next.supersetGroup, old != id {
            for item in items where item.supersetGroup == old { item.supersetGroup = id }
        }
        member.supersetGroup = id
        next.supersetGroup = id
    }

    /// Takes the member out of its superset; a group left with one member is dissolved.
    static func unlink<T: SupersetMember>(_ member: T, in items: [T]) {
        member.supersetGroup = nil
        cleanUp(items)
    }

    /// Splits the member's superset right after the member: everything that follows it
    /// in the group moves to a new group (and single leftovers are dissolved).
    static func unlinkFromNext<T: SupersetMember>(_ member: T, in items: [T]) {
        let members = group(of: member, in: items)
        guard member.supersetGroup != nil,
              let index = members.firstIndex(where: { $0 === member }),
              index + 1 < members.count else { return }
        let newID = (items.compactMap(\.supersetGroup).max() ?? 0) + 1
        for item in members[(index + 1)...] { item.supersetGroup = newID }
        cleanUp(items)
    }

    /// Dissolves groups that have fewer than two members (e.g. after deleting an exercise).
    static func cleanUp<T: SupersetMember>(_ items: [T]) {
        let counts = Dictionary(grouping: items.compactMap(\.supersetGroup), by: { $0 }).mapValues(\.count)
        for item in items {
            if let id = item.supersetGroup, (counts[id] ?? 0) < 2 { item.supersetGroup = nil }
        }
    }

    /// "A", "B", … per group id, in order of first appearance.
    static func labels<T: SupersetMember>(in items: [T]) -> [Int: String] {
        var labels: [Int: String] = [:]
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        for item in sorted(items) {
            guard let id = item.supersetGroup, labels[id] == nil, isInSuperset(item, in: items) else { continue }
            labels[id] = String(letters[labels.count % letters.count])
        }
        return labels
    }

    /// Rest only starts after the last exercise of a superset round.
    static func shouldStartRest<T: SupersetMember>(after member: T, in items: [T]) -> Bool {
        group(of: member, in: items).last === member
    }
}
